defmodule UiWeb.Contracts.ApiSpecTest do
  use ExUnit.Case, async: true

  alias UiWeb.Contracts.ApiSpec

  describe "endpoints/0" do
    test "returns all endpoint specifications" do
      endpoints = ApiSpec.endpoints()

      # Check that we have expected endpoints
      assert Map.has_key?(endpoints, "GET /health")
      assert Map.has_key?(endpoints, "GET /_health")
      assert Map.has_key?(endpoints, "GET /metrics")
      assert Map.has_key?(endpoints, "GET /api/v1/messages")
      assert Map.has_key?(endpoints, "POST /api/v1/messages")
      assert Map.has_key?(endpoints, "GET /api/v1/extensions")
      assert Map.has_key?(endpoints, "GET /api/v1/policies/:tenant_id")

      # Check structure of a sample endpoint
      messages_list = endpoints["GET /api/v1/messages"]
      assert Map.get(messages_list, :method) == "GET"
      assert Map.get(messages_list, :path) == "/api/v1/messages"
      assert Map.has_key?(messages_list, :request)
      assert Map.has_key?(messages_list, :response)
    end

    test "all endpoints have required fields" do
      ApiSpec.endpoints()
      |> Enum.each(fn {_key, spec} ->
        assert Map.has_key?(spec, :method)
        assert Map.has_key?(spec, :path)
        assert Map.has_key?(spec, :description)
        assert Map.has_key?(spec, :request)
        assert Map.has_key?(spec, :response)
      end)
    end

    test "all endpoints have response.success defined" do
      ApiSpec.endpoints()
      |> Enum.each(fn {_key, spec} ->
        response = Map.get(spec, :response)
        assert is_map(response)
        assert Map.has_key?(response, :success)
        
        success = Map.get(response, :success)
        assert is_map(success)
        assert Map.has_key?(success, :status)
        
        status = Map.get(success, :status)
        
        # DELETE endpoints (204) may have body: "empty" instead of schema
        # Export endpoints (200) may have body: "binary" instead of schema
        cond do
          status == 204 ->
            assert Map.has_key?(success, :body) || Map.has_key?(success, :schema)
          Map.has_key?(success, :body) and is_binary(Map.get(success, :body)) ->
            # Export endpoint with binary body
            assert Map.has_key?(success, :content_type) || Map.has_key?(success, :schema)
          true ->
            assert Map.has_key?(success, :schema)
        end
      end)
    end
  end

  describe "to_json_schema/0" do
    test "exports specification to JSON Schema format" do
      schema = ApiSpec.to_json_schema()

      assert is_map(schema)
      assert Map.has_key?(schema, "GET /api/v1/messages")

      # Check structure of exported schema
      messages_schema = schema["GET /api/v1/messages"]
      assert Map.has_key?(messages_schema, "method")
      assert Map.has_key?(messages_schema, "path")
      assert Map.has_key?(messages_schema, "description")
      assert Map.has_key?(messages_schema, "request")
      assert Map.has_key?(messages_schema, "response")
    end
  end
end

