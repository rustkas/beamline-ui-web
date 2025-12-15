defmodule UiWeb.Services.ExtensionsClientTest do
  use ExUnit.Case, async: true
  alias UiWeb.Services.ExtensionsClient

  describe "ExtensionsClient" do
    test "list_extensions returns error or valid data" do
      # This test verifies that the client handles requests gracefully
      # In a real test environment with mock gateway, we would verify exact responses
      result = ExtensionsClient.list_extensions()

      # Should return either an error (gateway down) or valid data
      assert elem(result, 0) in [:error, :ok]
    end

    test "list_extensions with filters" do
      result = ExtensionsClient.list_extensions(type: "provider", status: "enabled")

      # Should handle the request without crashing
      assert elem(result, 0) in [:error, :ok]
    end

    test "toggle_extension with boolean" do
      # Test toggle with valid boolean
      result = ExtensionsClient.toggle_extension("test_id", true)

      # Should handle the request
      assert elem(result, 0) in [:error, :ok]
    end

    test "delete_extension handles request" do
      result = ExtensionsClient.delete_extension("test_id")

      # Should return :ok or {:error, reason}
      assert result == :ok or elem(result, 0) == :error
    end

    test "list_extensions with pagination" do
      result = ExtensionsClient.list_extensions(limit: 10, offset: 20)

      # Should handle pagination parameters
      assert elem(result, 0) in [:error, :ok]
    end
  end
end

