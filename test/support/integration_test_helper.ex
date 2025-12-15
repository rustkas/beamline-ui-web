defmodule UiWeb.IntegrationTestHelper do
  @moduledoc """
  Helper module for integration tests, providing utilities for:
  - Gateway service management
  - Test data creation and cleanup
  - Event verification
  - Performance measurement
  """
  
  import ExUnit.Assertions
  
  alias UiWeb.Services.GatewayClient
  alias Phoenix.PubSub
  
  @gateway_url "http://localhost:8080"
  @default_timeout 5_000
  
  # Gateway Service Management
  
  @doc """
  Checks if Gateway service is running and accessible.
  """
  def gateway_available? do
    case Req.get("#{@gateway_url}/_health", receive_timeout: 2_000) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
  
  @doc """
  Waits for Gateway service to become available, with timeout.
  """
  def wait_for_gateway(timeout \\ @default_timeout) do
    wait_for_gateway(timeout, System.monotonic_time(:millisecond))
  end
  
  defp wait_for_gateway(timeout, start_time) do
    if gateway_available?() do
      {:ok, :gateway_ready}
    else
      elapsed = System.monotonic_time(:millisecond) - start_time
      if elapsed < timeout do
        Process.sleep(500)
        wait_for_gateway(timeout, start_time)
      else
        {:error, :gateway_timeout}
      end
    end
  end
  
  # Test Data Management
  
  @doc """
  Creates a test message with random content for isolation.
  """
  def create_test_message(overrides \\ %{}) do
    base_message = %{
      "content" => "Test message #{System.unique_integer([:positive])}",
      "type" => "integration_test",
      "metadata" => %{
        "test_id" => "test_#{System.unique_integer([:positive])}",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }
    
    Map.merge(base_message, overrides)
  end
  
  @doc """
  Creates multiple test messages for batch testing.
  """
  def create_test_messages(count, overrides \\ %{}) when is_integer(count) and count > 0 do
    for i <- 1..count do
      create_test_message(Map.merge(overrides, %{
        "content" => "Batch message #{i} of #{count}",
        "metadata" => Map.merge(overrides["metadata"] || %{}, %{"sequence" => i})
      }))
    end
  end
  
  @doc """
  Bulk creates messages using GatewayClient.
  """
  def bulk_create_messages(messages, _tenant \\ "test_tenant") do
    tasks = Enum.map(messages, fn message ->
      Task.async(fn ->
        GatewayClient.post_json("/api/v1/messages", message)
      end)
    end)
    
    Task.await_many(tasks, 30_000)
  end
  
  @doc """
  Cleans up test messages by deleting them.
  """
  def cleanup_test_messages(message_ids, _tenant \\ "test_tenant") do
    tasks = Enum.map(message_ids, fn message_id ->
      Task.async(fn ->
        GatewayClient.delete_json("/api/v1/messages/#{message_id}")
      end)
    end)
    
    Task.await_many(tasks, 30_000)
  end
  
  # Event Verification
  
  @doc """
  Subscribes to Phoenix PubSub events for a tenant.
  """
  def subscribe_to_events(tenant) do
    PubSub.subscribe(UiWeb.PubSub, "messages:#{tenant}")
  end
  
  @doc """
  Unsubscribes from Phoenix PubSub events.
  """
  def unsubscribe_from_events(tenant) do
    PubSub.unsubscribe(UiWeb.PubSub, "messages:#{tenant}")
  end
  
  @doc """
  Waits for a specific event type with timeout.
  """
  def wait_for_event(event_type, timeout \\ @default_timeout) do
    receive do
      {^event_type, data} -> {:ok, data}
    after
      timeout -> {:error, :timeout}
    end
  end
  
  @doc """
  Collects events for a specified duration.
  """
  def collect_events(duration_ms) do
    start_time = System.monotonic_time(:millisecond)
    collect_events(start_time, start_time + duration_ms, [])
  end
  
  defp collect_events(start_time, end_time, acc) do
    current_time = System.monotonic_time(:millisecond)
    
    if current_time >= end_time do
      Enum.reverse(acc)
    else
      remaining_time = end_time - current_time
      
      receive do
        event -> 
          collect_events(start_time, end_time, [event | acc])
      after
        remaining_time -> 
          Enum.reverse(acc)
      end
    end
  end
  
  @doc """
  Flushes all pending messages from the mailbox.
  """
  def flush_events do
    receive do
      _ -> flush_events()
    after
      100 -> :ok
    end
  end
  
  # Performance Measurement
  
  @doc """
  Measures the time taken to execute a function.
  """
  def measure_time(fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:millisecond)
    result = fun.()
    end_time = System.monotonic_time(:millisecond)
    
    {result, end_time - start_time}
  end
  
  @doc """
  Measures Gateway response time for a specific operation.
  """
  def measure_gateway_operation(operation, params \\ %{}) do
    case operation do
      :create_message ->
        message = create_test_message(params)
        {result, time} = measure_time(fn -> GatewayClient.post_json("/api/v1/messages", message) end)
        {result, time, :create_message}
        
      :get_message ->
        message_id = params["message_id"] || raise "message_id required for get operation"
        {result, time} = measure_time(fn -> GatewayClient.get_json("/api/v1/messages/#{message_id}") end)
        {result, time, :get_message}
        
      :update_message ->
        message_id = params["message_id"] || raise "message_id required for update operation"
        update_data = params["data"] || %{"content" => "Updated content"}
        {result, time} = measure_time(fn -> GatewayClient.put_json("/api/v1/messages/#{message_id}", update_data) end)
        {result, time, :update_message}
        
      :delete_message ->
        message_id = params["message_id"] || raise "message_id required for delete operation"
        {result, time} = measure_time(fn -> GatewayClient.delete_json("/api/v1/messages/#{message_id}") end)
        {result, time, :delete_message}
        
      _ ->
        raise "Unknown operation: #{operation}"
    end
  end
  
  # Assertion Helpers
  
  @doc """
  Asserts that a message was created successfully.
  """
  def assert_message_created({:ok, response}, expected_content \\ nil) do
    assert Map.has_key?(response, "message_id"), "Response should contain message_id"
    assert Map.has_key?(response, "trace_id"), "Response should contain trace_id"
    assert response["status"] == "created", "Message creation status should be 'created'"
    
    if expected_content do
      assert response["content"] == expected_content, "Message content should match"
    end
    
    response["message_id"]
  end
  
  @doc """
  Asserts that an event was received with expected data.
  """
  def assert_event_received(event_type, expected_data, timeout \\ @default_timeout) do
    case wait_for_event(event_type, timeout) do
      {:ok, event_data} ->
        Enum.each(expected_data, fn {key, expected_value} ->
          assert event_data[key] == expected_value, 
            "Event #{event_type} data[#{key}] should be #{inspect(expected_value)}, got #{inspect(event_data[key])}"
        end)
        {:ok, event_data}
        
      {:error, :timeout} ->
        flunk("Timeout waiting for event #{event_type}")
    end
  end
  
  @doc """
  Asserts that no event was received within timeout.
  """
  def assert_no_event_received(timeout \\ 500) do
    receive do
      event ->
        flunk("Unexpected event received: #{inspect(event)}")
    after
      timeout -> :ok
    end
  end
  
  # Stress Testing
  
  @doc """
  Runs a stress test with specified number of operations.
  """
  def stress_test(operation_count, operations \\ [:create_message], concurrency \\ 10) do
    # Generate operations
    operation_list = for i <- 1..operation_count do
      operation = Enum.random(operations)
      params = case operation do
        :create_message -> create_test_message(%{"sequence" => i})
        _ -> %{}
      end
      {operation, params}
    end
    
    # Split into chunks for concurrent execution
    chunks = Enum.chunk_every(operation_list, concurrency)
    
    start_time = System.monotonic_time(:millisecond)
    
    results = Enum.map(chunks, fn chunk ->
      Task.async(fn ->
        Enum.map(chunk, fn {operation, params} ->
          measure_gateway_operation(operation, params)
        end)
      end)
    end)
    |> Task.await_many(60_000)
    |> List.flatten()
    
    end_time = System.monotonic_time(:millisecond)
    total_time = end_time - start_time
    
    # Analyze results
    successful = Enum.count(results, fn
      {{:ok, _}, _time, _op} -> true
      _ -> false
    end)
    
    failed = length(results) - successful
    avg_time = results
    |> Enum.map(fn {_result, time, _op} -> time end)
    |> Enum.sum()
    |> then(fn total_time -> if length(results) > 0, do: div(total_time, length(results)), else: 0 end)
    
    %{
      total_operations: operation_count,
      successful: successful,
      failed: failed,
      total_time_ms: total_time,
      average_time_ms: avg_time,
      operations_per_second: div(operation_count * 1000, max(total_time, 1)),
      results: results
    }
  end
  
  # Configuration Validation
  
  @doc """
  Validates that all required configuration is present for integration tests.
  """
  def validate_integration_config do
    checks = [
      {:gateway_url, fn -> System.get_env("GATEWAY_URL") || @gateway_url end},
      {:gateway_available, &gateway_available?/0},
      {:phoenix_pubsub, fn -> Process.whereis(UiWeb.PubSub) != nil end},
      {:sse_bridge, fn -> Process.whereis(UiWeb.SSEBridge) != nil end}
    ]
    
    Enum.map(checks, fn {name, check_fn} ->
      try do
        result = check_fn.()
        {name, result}
      rescue
        _ -> {name, false}
      end
    end)
  end
  
  @doc """
  Prints integration test configuration validation results.
  """
  def print_integration_config do
    results = validate_integration_config()
    
    IO.puts("\n🔍 Integration Test Configuration Validation:")
    IO.puts("=" |> String.duplicate(50))
    
    Enum.each(results, fn {name, result} ->
      status = if result, do: "✅ PASS", else: "❌ FAIL"
      IO.puts("#{status} #{name}: #{inspect(result)}")
    end)
    
    all_passed = Enum.all?(results, fn {_name, result} -> result end)
    
    if all_passed do
      IO.puts("\n🚀 All integration tests ready to run!")
    else
      IO.puts("\n⚠️  Some integration tests may fail due to configuration issues.")
    end
    
    IO.puts("=" |> String.duplicate(50))
  end
end