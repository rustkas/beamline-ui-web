defmodule UiWeb.Test.MockGatewayTest do
  @moduledoc """
  Unit tests for Mock Gateway server.
  
  Validates that Mock Gateway correctly implements all required endpoints.
  """
  
  use ExUnit.Case
  alias UiWeb.Test.MockGateway
  
  @moduletag :integration
  
  setup do
    # Ensure Mock Gateway is running
    {:ok, _pid} = UiWeb.Test.MockGatewayServer.start(port: 8081)
    :ok
  end
  
  describe "Health endpoint" do
    test "GET /health returns valid response" do
      assert {:ok, %{body: body}} = Req.get("http://localhost:8081/health")
      
      assert body["status"] == "ok"
      assert is_map(body["nats"])
      assert is_boolean(body["nats"]["connected"])
      assert is_integer(body["timestamp_ms"])
    end
    
    test "GET /_health returns valid response (fallback)" do
      assert {:ok, %{body: body}} = Req.get("http://localhost:8081/_health")
      
      assert body["status"] == "ok"
      assert is_map(body["nats"])
    end
  end
  
  describe "Metrics endpoint" do
    test "GET /metrics returns valid response" do
      assert {:ok, %{body: body}} = Req.get("http://localhost:8081/metrics")
      
      assert is_number(body["rps"])
      assert is_map(body["latency"])
      assert is_number(body["latency"]["p50"])
      assert is_number(body["latency"]["p95"])
      assert is_number(body["latency"]["p99"])
      assert is_number(body["error_rate"])
    end
  end
  
  describe "Messages endpoints" do
    test "POST /api/v1/messages creates message" do
      message = %{
        "tenant_id" => "test_tenant",
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "test"})
      }
      
      assert {:ok, %{body: body}} = Req.post("http://localhost:8081/api/v1/messages", json: message)
      
      assert is_binary(body["message_id"])
      assert String.starts_with?(body["message_id"], "msg_")
      assert is_integer(body["ack_timestamp_ms"])
      assert body["status"] in ["published", "queued"]
    end
    
    test "POST /api/v1/messages rejects invalid request" do
      invalid_message = %{"invalid_field" => "value"}
      
      assert {:ok, %{status: 400, body: body}} = 
        Req.post("http://localhost:8081/api/v1/messages", json: invalid_message)
      
      assert is_map(body)
      assert is_binary(body["error"])
    end
    
    test "GET /api/v1/messages returns paginated list" do
      assert {:ok, %{body: body}} = Req.get("http://localhost:8081/api/v1/messages")
      
      assert is_list(body["items"])
      assert is_integer(body["total"])
      assert is_integer(body["page"])
    end
    
    test "GET /api/v1/messages accepts query parameters" do
      url = "http://localhost:8081/api/v1/messages?tenant_id=test&page=2&limit=10"
      
      assert {:ok, %{body: body}} = Req.get(url)
      
      assert is_list(body["items"])
      assert body["page"] == 2
    end
    
    test "GET /api/v1/messages/:id returns message details" do
      # First create a message
      message = %{
        "tenant_id" => "test_tenant",
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "test"})
      }
      
      {:ok, %{body: ack}} = Req.post("http://localhost:8081/api/v1/messages", json: message)
      message_id = ack["message_id"]
      
      # Then fetch it
      assert {:ok, %{body: body}} = Req.get("http://localhost:8081/api/v1/messages/#{message_id}")
      
      assert body["message_id"] == message_id
      assert is_binary(body["tenant_id"])
      assert is_binary(body["message_type"])
      assert is_binary(body["payload"])
      assert is_binary(body["status"])
      assert is_integer(body["created_at"])
    end
    
    test "GET /api/v1/messages/:id returns 404 for non-existent message" do
      assert {:ok, %{status: 404, body: body}} = 
        Req.get("http://localhost:8081/api/v1/messages/nonexistent")
      
      assert is_map(body)
      assert is_binary(body["error"])
    end
    
    test "DELETE /api/v1/messages/:id deletes message" do
      # First create a message
      message = %{
        "tenant_id" => "test_tenant",
        "message_type" => "chat",
        "payload" => Jason.encode!(%{text: "test"})
      }
      
      {:ok, %{body: ack}} = Req.post("http://localhost:8081/api/v1/messages", json: message)
      message_id = ack["message_id"]
      
      # Then delete it
      assert {:ok, %{status: 204}} = Req.delete("http://localhost:8081/api/v1/messages/#{message_id}")
    end
  end
  
  describe "Error handling" do
    test "returns 404 for unknown routes" do
      assert {:ok, %{status: 404, body: body}} = 
        Req.get("http://localhost:8081/unknown/route")
      
      assert is_map(body)
      assert is_binary(body["error"])
    end
  end
end

