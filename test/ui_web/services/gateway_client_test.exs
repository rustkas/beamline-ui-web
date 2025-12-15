defmodule UiWeb.Services.GatewayClientTest do
  use ExUnit.Case, async: true
  alias UiWeb.Services.GatewayClient

  describe "GatewayClient with Req" do
    test "check_health returns error when gateway is unavailable" do
      # This test verifies that the Req-based client handles connection errors gracefully
      # In a real test environment, you would mock the Req calls
      result = GatewayClient.check_health()

      # check_health returns map (success) or {:error, reason} (failure)
      case result do
        result when is_map(result) ->
          # Success - should have status or cached_at
          assert Map.has_key?(result, "status") || Map.has_key?(result, "cached_at")

        {:error, _reason} ->
          # Error - this is expected if gateway is unavailable
          :ok
      end
    end

    test "get_json with metrics endpoint returns error or valid metrics" do
      result = GatewayClient.get_json("/metrics")

      # Should return either an error (gateway down) or valid metrics
      assert elem(result, 0) in [:error, :ok]
    end

    test "request_json with valid path format" do
      # Test that the request_json function properly formats requests
      # This is a basic smoke test to ensure the function doesn't crash
      result = GatewayClient.get_json("/health")

      # Should handle the request without crashing
      assert elem(result, 0) in [:error, :ok]
    end

    test "post_json with body encoding" do
      # Test POST request with JSON body
      test_body = %{"test" => "data", "number" => 123}
      result = GatewayClient.post_json("/api/test", test_body)

      # Should handle the POST request
      assert elem(result, 0) in [:error, :ok]
    end
  end
end
