defmodule UiWeb.Schemas.MessageForm do
  @moduledoc """
  Embedded schema for Message form validation.
  
  Provides validation and conversion between API format and form format.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :type, :string
    field :status, :string, default: "pending"

    # Content fields
    field :prompt, :string
    field :response, :string
    field :model, :string
    field :temperature, :float

    # Metadata fields
    field :user_id, :string
    field :session_id, :string
    field :tenant, :string
    field :tags, {:array, :string}, default: []
  end

  @types ~w(chat code completion)
  @statuses ~w(pending processing completed failed)

  @required [:type, :prompt]
  @optional [:response, :model, :temperature, :user_id, :session_id, :tenant, :tags, :status]

  @doc """
  Creates a changeset for MessageForm.
  """
  def changeset(struct, attrs \\ %{}) do
    attrs = normalize_tags_input(attrs)

    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:prompt, max: 8000)
    |> validate_number(:temperature, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
  end

  defp normalize_tags_input(attrs) do
    case get_in(attrs, ["tags"]) || get_in(attrs, [:tags]) do
      tags when is_binary(tags) ->
        tags_list =
          tags
          |> String.split(~r/,\s*/)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        put_in(attrs, ["tags"], tags_list)

      _ ->
        attrs
    end
  end

  @doc """
  Converts API message format to MessageForm struct.
  """
  def from_api(message) when is_map(message) do
    %__MODULE__{
      type: message["type"] || message[:type],
      status: message["status"] || message[:status] || "pending",
      prompt: get_in(message, ["content", "prompt"]) || get_in(message, [:content, :prompt]),
      response: get_in(message, ["content", "response"]) || get_in(message, [:content, :response]),
      model: get_in(message, ["content", "model"]) || get_in(message, [:content, :model]),
      temperature: get_in(message, ["content", "temperature"]) || get_in(message, [:content, :temperature]),
      user_id: get_in(message, ["metadata", "user_id"]) || get_in(message, [:metadata, :user_id]),
      session_id: get_in(message, ["metadata", "session_id"]) || get_in(message, [:metadata, :session_id]),
      tenant: get_in(message, ["metadata", "tenant"]) || get_in(message, [:metadata, :tenant]),
      tags: normalize_tags(get_in(message, ["metadata", "tags"]) || get_in(message, [:metadata, :tags]) || [])
    }
  end

  @doc """
  Converts MessageForm to API payload format.
  """
  def to_api_params(%__MODULE__{} = form) do
    content = %{}
    content = if form.prompt, do: Map.put(content, "prompt", form.prompt), else: content
    content = if form.response, do: Map.put(content, "response", form.response), else: content
    content = if form.model, do: Map.put(content, "model", form.model), else: content
    content = if form.temperature, do: Map.put(content, "temperature", form.temperature), else: content

    metadata = %{}
    metadata = if form.user_id, do: Map.put(metadata, "user_id", form.user_id), else: metadata
    metadata = if form.session_id, do: Map.put(metadata, "session_id", form.session_id), else: metadata
    metadata = if form.tenant, do: Map.put(metadata, "tenant", form.tenant), else: metadata
    metadata = if form.tags && length(form.tags) > 0, do: Map.put(metadata, "tags", form.tags), else: metadata

    result = %{
      "type" => form.type,
      "status" => form.status || "pending"
    }

    result = if map_size(content) > 0, do: Map.put(result, "content", content), else: result
    result = if map_size(metadata) > 0, do: Map.put(result, "metadata", metadata), else: result

    result
  end

  defp normalize_tags(nil), do: []
  defp normalize_tags(tags) when is_list(tags), do: tags
  defp normalize_tags(tags) when is_binary(tags) do
    tags
    |> String.split(~r/,\s*/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
  defp normalize_tags(_), do: []
end

