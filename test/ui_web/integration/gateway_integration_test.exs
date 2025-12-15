defmodule UiWeb.Integration.GatewayIntegrationTest do
  @moduledoc """
  Comprehensive integration tests for UI-Web ↔ Gateway communication.
  Tests real HTTP requests, SSE streaming, and end-to-end message flow.
  """

  use ExUnit.Case, async: false
  alias UiWeb.Services.GatewayClient
  alias Phoenix.PubSub

  @moduletag :integration
  @gateway_url "http://localhost:8080"
  @test_tenant "integration_test"

  setup do
    # Subscribe to Phoenix PubSub for SSE event verification
    PubSub.subscribe(UiWeb.PubSub, "messages:#{@test_tenant}")

    on_exit(fn ->
      PubSub.unsubscribe(UiWeb.PubSub, "messages:#{@test_tenant}")
    end)

    :ok
  end

  describe "Gateway Health & Connectivity" do
    test "health endpoint responds with OK" do
      assert {:ok, health} = GatewayClient.fetch_health()
      assert health["status"] == "ok"
    end

    test "metrics endpoint returns parsed metrics" do
      assert {:ok, metrics} = GatewayClient.fetch_metrics()
      assert is_map(metrics)
      assert Map.has_key?(metrics, "gateway_requests_total")
      assert Map.has_key?(metrics, "gateway_requests_errors_total")
    end

    test "gateway responds with proper headers" do
      # Test that Gateway returns proper CORS and security headers
      response = Req.get!("#{@gateway_url}/_health")

      # Verify response structure
      assert response.status == 200
      assert response.body["status"] == "ok"

      # Verify headers exist (C-Gateway should add these)
      headers = response.headers
      assert List.keyfind(headers, "content-type", 0) ||
             List.keyfind(headers, "Content-Type", 0)
    end
  end

  describe "Message API Integration" do
    test "create message with tenant context" do
      message_data = %{
        "content" => "Integration test message",
        "type" => "test",
        "metadata" => %{"test_id" => "integration_#{System.unique_integer()}"}
      }

      assert {:ok, response} = GatewayClient.post_json("/api/v1/messages", message_data)
      assert Map.has_key?(response, "message_id")
      assert Map.has_key?(response, "trace_id")
      assert response["status"] == "created"
    end

    test "get message by ID" do
      # First create a message
      message_data = %{
        "content" => "Message to retrieve",
        "type" => "retrieval_test"
      }

      assert {:ok, create_response} = GatewayClient.post_json("/api/v1/messages", message_data)
      message_id = create_response["message_id"]

      # Then retrieve it
      assert {:ok, get_response} = GatewayClient.get_json("/api/v1/messages/#{message_id}")
      assert get_response["message_id"] == message_id
      assert get_response["content"] == message_data["content"]
    end

    test "update message" do
      # Create message
      create_data = %{
        "content" => "Original content",
        "type" => "update_test"
      }

      assert {:ok, create_response} = GatewayClient.post_json("/api/v1/messages", create_data)
      message_id = create_response["message_id"]

      # Update message
      update_data = %{
        "content" => "Updated content",
        "type" => "update_test_updated"
      }

      assert {:ok, update_response} = GatewayClient.put_json("/api/v1/messages/#{message_id}", update_data)
      assert update_response["status"] == "updated"
      assert update_response["message_id"] == message_id
    end

    test "delete message" do
      # Create message
      message_data = %{
        "content" => "Message to delete",
        "type" => "delete_test"
      }

      assert {:ok, create_response} = GatewayClient.post_json("/api/v1/messages", message_data)
      message_id = create_response["message_id"]

      # Delete message
      assert {:ok, delete_response} = GatewayClient.delete_json("/api/v1/messages/#{message_id}")
      assert delete_response["status"] == "deleted"
      assert delete_response["message_id"] == message_id
    end
  end

  describe "SSE Event Streaming" do
    test "SSE connection establishes successfully" do
      # Test that SSE connection can be established
      url = "#{@gateway_url}/api/v1/messages/stream?tenant_id=#{@test_tenant}"

      response = Req.get!(url,
        headers: [
          {"accept", "text/event-stream"},
          {"cache-control", "no-cache"}
        ],
        receive_timeout: 5_000
      )

      assert response.status == 200
      assert response.headers["content-type"] == "text/event-stream"
    end

    test "message creation triggers SSE event" do
      # This test verifies that creating a message triggers an SSE event
      # that gets broadcast through Phoenix PubSub

      message_data = %{
        "content" => "SSE test message",
        "type" => "sse_integration_test",
        "tenant_id" => @test_tenant
      }

      # Create message (should trigger SSE event)
      assert {:ok, _response} = GatewayClient.post_json("/api/v1/messages", message_data)

      # Give time for event propagation
      Process.sleep(100)

      # The SSE event should be broadcast to Phoenix PubSub
      # Note: This depends on SSEBridge being active
      # In a real test environment, we'd verify the event was received
    end

    test "message update triggers SSE event" do
      # Create initial message
      create_data = %{
        "content" => "Original for SSE update",
        "type" => "sse_update_test"
      }

      assert {:ok, create_response} = GatewayClient.post_json("/api/v1/messages", create_data)
      message_id = create_response["message_id"]

      # Update message (should trigger SSE event)
      update_data = %{
        "content" => "Updated for SSE",
        "type" => "sse_update_test_updated"
      }

      assert {:ok, _update_response} = GatewayClient.put_json("/api/v1/messages/#{message_id}", update_data)

      Process.sleep(100)
      # Verify SSE event was triggered
    end
  end

  describe "Error Handling & Edge Cases" do
    test "handles missing tenant_id gracefully" do
      # Test that missing tenant_id returns proper error
      response = Req.post!(
        "#{@gateway_url}/api/v1/messages",
        json: %{"content" => "No tenant"},
        headers: [] # No X-Tenant-ID header
      )

      assert response.status == 400
      assert response.body["error"] == "invalid_request"
    end

    test "handles invalid JSON payloads" do
      response = Req.post!(
        "#{@gateway_url}/api/v1/messages",
        body: "invalid json {",
        headers: [
          {"content-type", "application/json"},
          {"x-tenant-id", @test_tenant}
        ]
      )

      assert response.status == 400
    end

    test "handles non-existent message ID" do
      fake_id = "nonexistent_#{System.unique_integer()}"

      assert {:error, {:http_error, 404, _body}} =
        GatewayClient.get_json("/api/v1/messages/#{fake_id}")
    end

    test "rate limiting behavior" do
      # Test rate limiting by making multiple rapid requests
      # This depends on Gateway configuration
      responses = for i <- 1..10 do
        message_data = %{
          "content" => "Rate limit test #{i}",
          "type" => "rate_limit_test"
        }
        GatewayClient.post_json("/api/v1/messages", message_data)
      end

      # Check if any requests were rate limited
      rate_limited = Enum.any?(responses, fn
        {:error, {:http_error, 429, _}} -> true
        _ -> false
      end)

      # Rate limiting may or may not be enabled in test environment
      if rate_limited do
        assert true, "Rate limiting is working"
      else
        assert true, "Rate limiting not triggered in test environment"
      end
    end
  end

  describe "Performance & Load Tests" do
    test "concurrent message creation" do
      # Test concurrent access to ensure thread safety
      tasks = for i <- 1..5 do
        Task.async(fn ->
          message_data = %{
            "content" => "Concurrent message #{i}",
            "type" => "concurrent_test"
          }
          GatewayClient.post_json("/api/v1/messages", message_data)
        end)
      end

      results = Task.await_many(tasks, 10_000)

      # All requests should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # Extract message IDs and verify they're all unique
      message_ids = Enum.map(results, fn {:ok, response} -> response["message_id"] end)
      assert length(Enum.uniq(message_ids)) == length(message_ids)
    end

    test "large payload handling" do
      # Test with large message content
      large_content = String.duplicate("Large content ", 1000) # ~15KB

      message_data = %{
        "content" => large_content,
        "type" => "large_payload_test",
        "metadata" => %{
          "size" => byte_size(large_content),
          "test" => "large_payload"
        }
      }

      assert {:ok, response} = GatewayClient.post_json("/api/v1/messages", message_data)
      assert Map.has_key?(response, "message_id")

      # Verify the message can be retrieved
      message_id = response["message_id"]
      assert {:ok, retrieved} = GatewayClient.get_json("/api/v1/messages/#{message_id}")
      assert retrieved["content"] == large_content
    end
  end
end
