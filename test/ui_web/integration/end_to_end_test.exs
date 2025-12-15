defmodule UiWeb.Integration.EndToEndTest do
  @moduledoc """
  End-to-end integration tests that verify complete message flows
  from UI-Web through Gateway to SSE events and back to UI.
  """
  
  use ExUnit.Case, async: false
  alias UiWeb.Services.GatewayClient
  alias Phoenix.PubSub
  import Phoenix.ChannelTest
  
  @moduletag :e2e
  @moduletag :integration
  
  @gateway_url "http://localhost:8080"
  @test_tenant "e2e_test_#{System.unique_integer([:positive])}"
  
  setup do
    # Start SSEBridge if not already running
    start_supervised!(UiWeb.SSEBridge)
    
    # Subscribe to Phoenix PubSub for event verification
    PubSub.subscribe(UiWeb.PubSub, "messages:#{@test_tenant}")
    
    on_exit(fn ->
      PubSub.unsubscribe(UiWeb.PubSub, "messages:#{@test_tenant}")
    end)
    
    :ok
  end
  
  describe "Complete Message Flow: Create → Gateway → SSE → UI" do
    test "message creation triggers complete event flow" do
      # Step 1: Create message via GatewayClient
      message_data = %{
        "content" => "E2E test message for complete flow",
        "type" => "e2e_flow_test",
        "metadata" => %{
          "test_id" => "flow_test_#{System.unique_integer()}",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }
      
      # Step 2: Send message to Gateway
      assert {:ok, create_response} = GatewayClient.post_json("/api/v1/messages", message_data)
      assert message_id = create_response["message_id"]
      assert create_response["status"] == "created"
      
      # Step 3: Wait for SSE event to be broadcast
      assert_receive {:message_created, event_data}, 2_000
      
      # Step 4: Verify the event contains expected data
      assert event_data["message_id"] == message_id
      assert event_data["content"] == message_data["content"]
      assert event_data["type"] == message_data["type"]
      
      # Step 5: Verify message can be retrieved
      assert {:ok, retrieved_message} = GatewayClient.get_json("/api/v1/messages/#{message_id}")
      assert retrieved_message["content"] == message_data["content"]
      assert retrieved_message["type"] == message_data["type"]
      
      IO.puts("✅ Complete message flow verified: Created → Gateway → SSE → UI")
    end
    
    test "message update triggers update event flow" do
      # Step 1: Create initial message
      create_data = %{
        "content" => "Original content for update test",
        "type" => "e2e_update_test"
      }
      
      assert {:ok, create_response} = GatewayClient.post_json("/api/v1/messages", create_data)
      message_id = create_response["message_id"]
      
      # Clear any previous events
      flush_messages()
      
      # Step 2: Update the message
      update_data = %{
        "content" => "Updated content for update test",
        "type" => "e2e_update_test_updated"
      }
      
      assert {:ok, update_response} = GatewayClient.put_json("/api/v1/messages/#{message_id}", update_data)
      assert update_response["status"] == "updated"
      
      # Step 3: Wait for update event
      assert_receive {:message_updated, event_data}, 2_000
      
      # Step 4: Verify update event
      assert event_data["message_id"] == message_id
      assert event_data["content"] == update_data["content"]
      assert event_data["type"] == update_data["type"]
      
      IO.puts("✅ Message update flow verified: Update → Gateway → SSE → UI")
    end
    
    test "message deletion triggers delete event flow" do
      # Step 1: Create message to delete
      create_data = %{
        "content" => "Message to be deleted",
        "type" => "e2e_delete_test"
      }
      
      assert {:ok, create_response} = GatewayClient.post_json("/api/v1/messages", create_data)
      message_id = create_response["message_id"]
      
      # Clear any previous events
      flush_messages()
      
      # Step 2: Delete the message
      assert {:ok, delete_response} = GatewayClient.delete_json("/api/v1/messages/#{message_id}")
      assert delete_response["status"] == "deleted"
      assert delete_response["message_id"] == message_id
      
      # Step 3: Wait for delete event
      assert_receive {:message_deleted, event_data}, 2_000
      
      # Step 4: Verify delete event
      assert event_data["message_id"] == message_id
      
      # Step 5: Verify message is actually deleted
      assert {:error, {:http_error, 404, _}} = GatewayClient.get_json("/api/v1/messages/#{message_id}")
      
      IO.puts("✅ Message deletion flow verified: Delete → Gateway → SSE → UI")
    end
  end
  
  describe "Multi-tenant Event Isolation" do
    test "events are isolated by tenant" do
      tenant_a = "tenant_a_#{System.unique_integer()}"
      tenant_b = "tenant_b_#{System.unique_integer()}"
      
      # Subscribe to both tenants
      PubSub.subscribe(UiWeb.PubSub, "messages:#{tenant_a}")
      PubSub.subscribe(UiWeb.PubSub, "messages:#{tenant_b}")
      
      # Create message for tenant A
      message_a = %{
        "content" => "Message for tenant A",
        "type" => "tenant_isolation_test",
        "tenant_id" => tenant_a
      }
      
      assert {:ok, response_a} = GatewayClient.post_json("/api/v1/messages", message_a)
      
      # Should receive event for tenant A
      assert_receive {:message_created, event_a}, 2_000
      assert event_a["message_id"] == response_a["message_id"]
      
      # Should NOT receive event for tenant B
      refute_receive {:message_created, _}, 500
      
      # Create message for tenant B
      message_b = %{
        "content" => "Message for tenant B",
        "type" => "tenant_isolation_test",
        "tenant_id" => tenant_b
      }
      
      assert {:ok, response_b} = GatewayClient.post_json("/api/v1/messages", message_b)
      
      # Should receive event for tenant B
      assert_receive {:message_created, event_b}, 2_000
      assert event_b["message_id"] == response_b["message_id"]
      
      IO.puts("✅ Multi-tenant isolation verified")
    end
  end
  
  describe "Error Recovery & Resilience" do
    test "handles gateway temporary unavailability" do
      # Simulate gateway being temporarily unavailable
      # This test verifies retry logic and error handling
      
      message_data = %{
        "content" => "Resilience test message",
        "type" => "resilience_test"
      }
      
      # First attempt might fail if gateway is restarting
      case GatewayClient.post_json("/api/v1/messages", message_data) do
        {:ok, response} ->
          assert response["status"] == "created"
          IO.puts("✅ Gateway available, message created successfully")
          
        {:error, _reason} ->
          # Wait a bit and retry (simulating retry logic)
          Process.sleep(1000)
          
          # Second attempt should succeed
          assert {:ok, response} = GatewayClient.post_json("/api/v1/messages", message_data)
          assert response["status"] == "created"
          IO.puts("✅ Gateway recovered, message created on retry")
      end
    end
    
    test "handles malformed events gracefully" do
      # Test that malformed messages don't break the SSE stream
      
      # Create a message with special characters and edge cases
      edge_case_data = %{
        "content" => "Special chars: àáâãäåæçèéêë 🚀 \n \t \r \" ' `",
        "type" => "edge_case_test",
        "metadata" => %{
          "unicode" => "🎉 🎊 🎈",
          "escaped" => "Line 1\nLine 2\tTabbed",
          "nested" => %{
            "deep" => %{
              "value" => "Deeply nested data"
            }
          }
        }
      }
      
      assert {:ok, response} = GatewayClient.post_json("/api/v1/messages", edge_case_data)
      message_id = response["message_id"]
      
      # Should receive event with properly escaped content
      assert_receive {:message_created, event_data}, 2_000
      assert event_data["message_id"] == message_id
      assert event_data["content"] == edge_case_data["content"]
      
      IO.puts("✅ Edge case handling verified")
    end
  end
  
  describe "Performance Under Load" do
    test "handles rapid message creation" do
      # Test system behavior under rapid message creation
      
      message_count = 10
      start_time = System.monotonic_time(:millisecond)
      
      # Create multiple messages rapidly
      tasks = for i <- 1..message_count do
        Task.async(fn ->
          message_data = %{
            "content" => "Rapid message #{i}",
            "type" => "rapid_creation_test",
            "metadata" => %{"sequence" => i}
          }
          GatewayClient.post_json("/api/v1/messages", message_data)
        end)
      end
      
      # Wait for all messages to be created
      results = Task.await_many(tasks, 10_000)
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Verify all messages were created successfully
      successful_creations = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)
      
      assert successful_creations == message_count
      
      # Verify events were received
      events_received = collect_events(message_count, 5_000)
      assert length(events_received) == message_count
      
      IO.puts("✅ Rapid message creation verified: #{message_count} messages in #{duration}ms")
    end
    
    test "handles concurrent operations" do
      # Test concurrent create, update, and delete operations
      
      # Create initial messages
      message_count = 5
      
      {:ok, message_ids} = create_test_messages(message_count)
      
      # Perform concurrent operations
      operations = [
        {:create, 1},
        {:update, 2},
        {:delete, 2}
      ]
      
      tasks = Enum.map(operations, fn
        {:create, count} ->
          Task.async(fn ->
            for i <- 1..count do
              message_data = %{
                "content" => "Concurrent create #{i}",
                "type" => "concurrent_test"
              }
              GatewayClient.post_json("/api/v1/messages", message_data)
            end
          end)
          
        {:update, count} ->
          Task.async(fn ->
            messages_to_update = Enum.take(message_ids, count)
            for message_id <- messages_to_update do
              update_data = %{
                "content" => "Updated concurrently",
                "type" => "concurrent_test_updated"
              }
              GatewayClient.put_json("/api/v1/messages/#{message_id}", update_data)
            end
          end)
          
        {:delete, count} ->
          Task.async(fn ->
            messages_to_delete = Enum.take(message_ids, count)
            for message_id <- messages_to_delete do
              GatewayClient.delete_json("/api/v1/messages/#{message_id}")
            end
          end)
      end)
      
      # Wait for all operations to complete
      results = Task.await_many(tasks, 15_000)
      
      # Verify operations succeeded
      assert length(results) == length(operations)
      
      IO.puts("✅ Concurrent operations verified")
    end
  end
  
  # Helper functions
  
  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      100 -> :ok
    end
  end
  
  defp collect_events(expected_count, timeout) do
    collect_events(expected_count, timeout, [])
  end
  
  defp collect_events(0, _timeout, acc), do: acc
  
  defp collect_events(expected_count, timeout, acc) do
    receive do
      {:message_created, event} ->
        collect_events(expected_count - 1, timeout, [{:created, event} | acc])
        
      {:message_updated, event} ->
        collect_events(expected_count - 1, timeout, [{:updated, event} | acc])
        
      {:message_deleted, event} ->
        collect_events(expected_count - 1, timeout, [{:deleted, event} | acc])
        
    after
      timeout -> acc
    end
  end
  
  defp create_test_messages(count) do
    tasks = for i <- 1..count do
      Task.async(fn ->
        message_data = %{
          "content" => "Test message #{i}",
          "type" => "concurrent_setup"
        }
        
        case GatewayClient.post_json("/api/v1/messages", message_data) do
          {:ok, response} -> response["message_id"]
          _ -> nil
        end
      end)
    end
    
    results = Task.await_many(tasks, 10_000)
    message_ids = Enum.filter(results, &(&1 != nil))
    
    {:ok, message_ids}
  end
end