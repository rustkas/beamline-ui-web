defmodule UiWeb.Schemas.Message do
  @moduledoc """
  Message schema and changeset for validation.
  
  This schema represents a message in the system with validation rules.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  
  schema "messages" do
    field :tenant_id, :string
    field :status, :string
    field :trace_id, :string
    field :request_id, :string
    field :model, :string
    field :content, :string
    field :response, :string
    field :message_type, :string
    field :payload, :string
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
  end

  @required_fields [:tenant_id, :model]
  @optional_fields [:id, :status, :trace_id, :request_id, :content, :response, :message_type, :payload, :created_at, :updated_at]

  @doc """
  Creates a changeset for a message.
  """
  def changeset(message, attrs \\ %{}) do
    message
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:tenant_id, min: 1, max: 255)
    |> validate_length(:model, min: 1, max: 255)
    |> validate_inclusion(:status, ["pending", "processing", "success", "error", "cancelled"], message: "must be one of: pending, processing, success, error, cancelled")
    |> validate_length(:content, max: 10_000)
  end

  @doc """
  Creates a new changeset for a message.
  """
  def new_changeset(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
end

