defmodule UiWeb.Services.ClientHelpersTest do
  use ExUnit.Case, async: true

  alias UiWeb.Services.ClientHelpers

  describe "build_query_params/1" do
    test "filters out nil values" do
      result = ClientHelpers.build_query_params([status: "active", type: nil, search: "test"])
      assert result == %{status: "active", search: "test"}
    end

    test "filters out empty string values" do
      result = ClientHelpers.build_query_params([status: "active", type: "", search: "test"])
      assert result == %{status: "active", search: "test"}
    end

    test "keeps valid values" do
      result = ClientHelpers.build_query_params([status: "active", limit: 20, offset: 0])
      assert result == %{status: "active", limit: 20, offset: 0}
    end

    test "handles empty list" do
      result = ClientHelpers.build_query_params([])
      assert result == %{}
    end
  end

  describe "normalize_response/1" do
    test "returns success for valid map response" do
      result = ClientHelpers.normalize_response({:ok, %{"data" => [1, 2, 3]}})
      assert result == {:ok, %{"data" => [1, 2, 3]}}
    end

    test "returns success for valid list response" do
      result = ClientHelpers.normalize_response({:ok, [1, 2, 3]})
      assert result == {:ok, [1, 2, 3]}
    end

    test "converts error in body to error tuple" do
      result = ClientHelpers.normalize_response({:ok, %{"error" => "Not found"}})
      assert {:error, %{reason: :gateway_error, details: _, message: "Not found"}} = result
    end

    test "keeps success when error is one of many fields" do
      result = ClientHelpers.normalize_response({:ok, %{"data" => [], "error" => nil}})
      assert result == {:ok, %{"data" => [], "error" => nil}}
    end

    test "handles empty body (204 No Content)" do
      result = ClientHelpers.normalize_response({:ok, ""})
      assert result == {:ok, %{}}
    end

    test "handles nil body" do
      result = ClientHelpers.normalize_response({:ok, nil})
      assert result == {:ok, %{}}
    end

    test "decodes JSON string" do
      json_string = Jason.encode!(%{"data" => [1, 2]})
      result = ClientHelpers.normalize_response({:ok, json_string})
      assert result == {:ok, %{"data" => [1, 2]}}
    end

    test "keeps binary if not JSON" do
      result = ClientHelpers.normalize_response({:ok, "not json"})
      assert result == {:ok, "not json"}
    end

    test "preserves error tuples" do
      result = ClientHelpers.normalize_response({:error, :timeout})
      assert result == {:error, :timeout}
    end

    test "preserves HTTP error tuples" do
      result = ClientHelpers.normalize_response({:error, {:http_error, 404, %{"error" => "Not found"}}})
      assert result == {:error, {:http_error, 404, %{"error" => "Not found"}}}
    end

    test "handles invalid response format" do
      result = ClientHelpers.normalize_response({:ok, 123})
      # normalize_response wraps the original tuple in invalid_response
      assert {:error, {:invalid_response, {:ok, 123}}} = result
    end
  end

  describe "handle_delete_response/1" do
    test "converts success to :ok" do
      result = ClientHelpers.handle_delete_response({:ok, %{"deleted" => true}})
      assert result == :ok
    end

    test "converts success with empty body to :ok" do
      result = ClientHelpers.handle_delete_response({:ok, %{}})
      assert result == :ok
    end

    test "preserves errors" do
      result = ClientHelpers.handle_delete_response({:error, :not_found})
      assert result == {:error, :not_found}
    end

    test "preserves HTTP errors" do
      result = ClientHelpers.handle_delete_response({:error, {:http_error, 500, %{}}})
      assert result == {:error, {:http_error, 500, %{}}}
    end
  end

  describe "extract_items/1" do
    test "extracts items from data key" do
      result = ClientHelpers.extract_items(%{"data" => [1, 2, 3], "pagination" => %{}})
      assert result == [1, 2, 3]
    end

    test "extracts items from items key" do
      result = ClientHelpers.extract_items(%{"items" => [1, 2, 3]})
      assert result == [1, 2, 3]
    end

    test "returns list directly if it's a list" do
      result = ClientHelpers.extract_items([1, 2, 3])
      assert result == [1, 2, 3]
    end

    test "returns empty list for invalid input" do
      result = ClientHelpers.extract_items(%{"other" => "value"})
      assert result == []
    end

    test "returns empty list for non-map, non-list" do
      result = ClientHelpers.extract_items("not a list")
      assert result == []
    end
  end
end

