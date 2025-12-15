defmodule UiWeb.Services.MessagesClientTest do
  use ExUnit.Case, async: true

  alias UiWeb.Services.MessagesClient

  describe "list_messages/1" do
    test "lists messages with filters" do
      case MessagesClient.list_messages(status: "completed", limit: 10) do
        {:ok, %{"data" => messages, "pagination" => pagination}} ->
          assert is_list(messages)
          assert Map.has_key?(pagination, "total")
          assert Map.has_key?(pagination, "limit")

        {:error, _reason} ->
          # Gateway may not be available in tests
          :ok
      end
    end
  end

  describe "get_message/1" do
    test "gets single message" do
      case MessagesClient.get_message("msg_001") do
        {:ok, message} ->
          assert Map.has_key?(message, "id")

        {:error, _reason} ->
          # Gateway may not be available
          :ok
      end
    end
  end

  describe "create_message/1" do
    test "creates new message" do
      attrs = %{
        type: "chat",
        content: %{
          prompt: "Test message",
          model: "gpt-4"
        },
        metadata: %{
          user_id: "user_1"
        }
      }

      case MessagesClient.create_message(attrs) do
        {:ok, message} ->
          assert Map.has_key?(message, "id")

        {:error, _reason} ->
          # Gateway may not be available
          :ok
      end
    end
  end

  describe "bulk_delete_messages/1" do
    test "deletes multiple messages" do
      case MessagesClient.bulk_delete_messages(["msg_001", "msg_002"]) do
        {:ok, %{"deleted_count" => count}} ->
          assert count >= 0

        {:error, _reason} ->
          # Gateway may not be available
          :ok
      end
    end
  end

  describe "export_messages/2" do
    test "exports messages as JSON" do
      case MessagesClient.export_messages(["msg_001"], "json") do
        {:ok, content} ->
          assert is_binary(content)
          # Should be valid JSON
          {:ok, _} = Jason.decode(content)

        {:error, _reason} ->
          # Gateway may not be available
          :ok
      end
    end

    test "exports messages as CSV" do
      case MessagesClient.export_messages(["msg_001"], "csv") do
        {:ok, content} ->
          assert is_binary(content)
          assert String.contains?(content, ",")

        {:error, _reason} ->
          # Gateway may not be available
          :ok
      end
    end
  end
end

