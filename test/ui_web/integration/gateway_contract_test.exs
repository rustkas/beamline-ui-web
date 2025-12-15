defmodule UiWeb.Integration.GatewayContractTest do
  @moduledoc """
  Contract tests for UI-Web ↔ C-Gateway API.
  
  Validates that Gateway API contracts match expected schemas.
  These tests ensure backward compatibility and catch breaking changes.
  """
  
  use ExUnit.Case
  alias UiWeb.Services.GatewayClient
  alias UiWeb.Test.SchemaValidators
  
  @moduletag :integration
  
  describe "Health endpoint" do
    test "returns valid schema" do
      assert {:ok, health} = GatewayClient.fetch_health()
      
      # Required fields
      assert is_binary(health["status"])
      assert health["status"] in ["ok", "degraded", "unhealthy"]
      assert is_map(health["nats"])
      assert is_boolean(health["nats"]["connected"])
      assert is_integer(health["timestamp_ms"])
      
      # Schema validation
      assert SchemaValidators.validate_health_schema(health)
    end
  end
  
  describe "Metrics endpoint" do
    test "returns valid schema" do
      assert {:ok, metrics} = GatewayClient.fetch_metrics()
      
      # Optional numeric fields
      assert is_number(metrics["rps"]) or is_nil(metrics["rps"])
      assert is_map(metrics["latency"])
      assert is_number(metrics["latency"]["p50"])
      assert is_number(metrics["latency"]["p95"])
      assert is_number(metrics["latency"]["p99"])
      assert is_number(metrics["error_rate"]) or is_nil(metrics["error_rate"])
      
      # Schema validation
      assert SchemaValidators.validate_metrics_schema(metrics)
    end
  end
  
  describe "POST /api/v1/messages" do
    test "accepts CreateMessageDto" do
      message = %{
        "tenant_id" => "test_tenant",
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "test"}),
        "trace_id" => "trace_#{System.system_time()}"
      }
      
      assert {:ok, ack} = GatewayClient.post_json("/api/v1/messages", message)
      
      # Response validation
      assert is_binary(ack["message_id"])
      assert String.starts_with?(ack["message_id"], "msg_")
      assert is_integer(ack["ack_timestamp_ms"])
      assert ack["status"] in ["published", "queued"]
      
      # Schema validation
      assert SchemaValidators.validate_ack_schema(ack)
    end
    
    test "rejects invalid CreateMessageDto" do
      invalid_message = %{"invalid_field" => "value"}
      
      assert {:error, response} = GatewayClient.post_json("/api/v1/messages", invalid_message)
      assert is_map(response)
      assert response[:status] in [400, 422] or elem(response, 0) == :http_error
    end
  end
  
  describe "GET /api/v1/messages" do
    test "returns paginated list" do
      assert {:ok, response} = GatewayClient.get_json("/api/v1/messages")
      
      assert is_list(response["items"])
      assert is_integer(response["total"])
      assert is_integer(response["page"])
    end
    
    test "accepts filter parameters" do
      params = %{tenant_id: "test", status: "completed", page: 2}
      assert {:ok, _response} = GatewayClient.get_json("/api/v1/messages", params)
    end
  end
  
  describe "GET /api/v1/messages/:id" do
    setup do
      # Create test message first
      message = %{
        "tenant_id" => "test_tenant",
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "test"}),
        "trace_id" => "trace_#{System.system_time()}"
      }
      
      {:ok, ack} = GatewayClient.post_json("/api/v1/messages", message)
      {:ok, message_id: ack["message_id"]}
    end
    
    test "returns message details", %{message_id: id} do
      assert {:ok, message} = GatewayClient.get_json("/api/v1/messages/#{id}")
      
      assert message["message_id"] == id
      assert is_binary(message["tenant_id"])
      assert is_binary(message["message_type"])
      assert is_binary(message["payload"])
      assert is_binary(message["status"])
      assert is_integer(message["created_at"])
    end
  end
end

