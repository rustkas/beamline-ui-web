defmodule UiWeb.Schemas.MessageFormTest do
  use ExUnit.Case, async: true

  alias UiWeb.Schemas.MessageForm

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        "type" => "chat",
        "prompt" => "Test prompt"
      }

      changeset = MessageForm.changeset(%MessageForm{}, attrs)

      assert changeset.valid?
      assert changeset.changes.type == "chat"
      assert changeset.changes.prompt == "Test prompt"
    end

    test "invalid when type is missing" do
      attrs = %{"prompt" => "Test prompt"}

      changeset = MessageForm.changeset(%MessageForm{}, attrs)

      refute changeset.valid?
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid when prompt is missing" do
      attrs = %{"type" => "chat"}

      changeset = MessageForm.changeset(%MessageForm{}, attrs)

      refute changeset.valid?
      assert %{prompt: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid when type is not in allowed list" do
      attrs = %{
        "type" => "invalid",
        "prompt" => "Test prompt"
      }

      changeset = MessageForm.changeset(%MessageForm{}, attrs)

      refute changeset.valid?
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "invalid when temperature is out of range" do
      attrs = %{
        "type" => "chat",
        "prompt" => "Test prompt",
        "temperature" => 3.0
      }

      changeset = MessageForm.changeset(%MessageForm{}, attrs)

      refute changeset.valid?
      assert %{temperature: ["must be less than or equal to 2.0"]} = errors_on(changeset)
    end

    test "normalizes tags from comma-separated string" do
      attrs = %{
        "type" => "chat",
        "prompt" => "Test prompt",
        "tags" => "tag1, tag2, tag3"
      }

      changeset = MessageForm.changeset(%MessageForm{}, attrs)

      assert changeset.valid?
      assert changeset.changes.tags == ["tag1", "tag2", "tag3"]
    end
  end

  describe "from_api/1" do
    test "converts API message to MessageForm" do
      message = %{
        "id" => "msg_001",
        "type" => "chat",
        "status" => "completed",
        "content" => %{
          "prompt" => "Hello",
          "response" => "Hi",
          "model" => "gpt-4",
          "temperature" => 0.7
        },
        "metadata" => %{
          "user_id" => "user_123",
          "session_id" => "session_456",
          "tenant" => "tenant_dev",
          "tags" => ["test", "demo"]
        }
      }

      form = MessageForm.from_api(message)

      assert form.type == "chat"
      assert form.status == "completed"
      assert form.prompt == "Hello"
      assert form.response == "Hi"
      assert form.model == "gpt-4"
      assert form.temperature == 0.7
      assert form.user_id == "user_123"
      assert form.session_id == "session_456"
      assert form.tenant == "tenant_dev"
      assert form.tags == ["test", "demo"]
    end
  end

  describe "to_api_params/1" do
    test "converts MessageForm to API payload" do
      form = %MessageForm{
        type: "chat",
        status: "pending",
        prompt: "Test prompt",
        response: "Test response",
        model: "gpt-4",
        temperature: 0.7,
        user_id: "user_123",
        session_id: "session_456",
        tenant: "tenant_dev",
        tags: ["test", "demo"]
      }

      params = MessageForm.to_api_params(form)

      assert params["type"] == "chat"
      assert params["status"] == "pending"
      assert params["content"]["prompt"] == "Test prompt"
      assert params["content"]["response"] == "Test response"
      assert params["content"]["model"] == "gpt-4"
      assert params["content"]["temperature"] == 0.7
      assert params["metadata"]["user_id"] == "user_123"
      assert params["metadata"]["session_id"] == "session_456"
      assert params["metadata"]["tenant"] == "tenant_dev"
      assert params["metadata"]["tags"] == ["test", "demo"]
    end

    test "omits empty fields from API payload" do
      form = %MessageForm{
        type: "chat",
        prompt: "Test prompt"
      }

      params = MessageForm.to_api_params(form)

      assert params["type"] == "chat"
      assert params["status"] == "pending"
      assert params["content"]["prompt"] == "Test prompt"
      refute Map.has_key?(params["content"], "response")
      refute Map.has_key?(params, "metadata")
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

