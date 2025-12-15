defmodule UiWeb.Services.MessagesClient do
  @moduledoc """
  HTTP client for Messages API.

  Provides:
  - list_messages/1 - List with filters and pagination
  - get_message/1 - Get single message
  - create_message/1 - Create new message
  - update_message/2 - Update existing message
  - delete_message/1 - Delete single message
  - bulk_delete_messages/1 - Delete multiple messages
  - export_messages/2 - Export messages to JSON/CSV
  """

  require Logger

  alias UiWeb.Services.GatewayClient
  alias UiWeb.Services.ClientHelpers

  @doc """
  List messages with filters.

  ## Options
    * `:status` - Filter by status
    * `:type` - Filter by type
    * `:search` - Search query
    * `:from_date` - Start date (ISO8601)
    * `:to_date` - End date (ISO8601)
    * `:limit` - Page size (default: 50)
    * `:offset` - Pagination offset
    * `:sort` - Sort field (created_at/updated_at/status)
    * `:order` - Sort order (asc/desc)
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec list_messages(keyword()) :: {:ok, map()} | {:error, term()}
  def list_messages(opts \\ []) do
    params = build_query_params(opts)
    client_opts = extract_client_opts(opts)
    # operation will be auto-inferred as :list by GatewayClient.get_json
    GatewayClient.get_json("/api/v1/messages", Keyword.merge([params: params], client_opts))
  end

  @doc """
  Get single message with full details.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec get_message(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_message(message_id, opts \\ []) do
    client_opts = extract_client_opts(opts)
    GatewayClient.get_json("/api/v1/messages/#{message_id}", Keyword.merge([operation: :get], client_opts))
  end

  @doc """
  Create new message.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec create_message(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_message(attrs, opts \\ []) do
    client_opts = extract_client_opts(opts)
    GatewayClient.post_json("/api/v1/messages", attrs, Keyword.merge([operation: :create], client_opts))
  end

  @doc """
  Update existing message.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec update_message(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update_message(message_id, attrs, opts \\ []) do
    client_opts = extract_client_opts(opts)
    GatewayClient.put_json("/api/v1/messages/#{message_id}", attrs, Keyword.merge([operation: :update], client_opts))
  end

  @doc """
  Delete single message.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec delete_message(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_message(message_id, opts \\ []) do
    client_opts = extract_client_opts(opts)
    GatewayClient.delete("/api/v1/messages/#{message_id}", Keyword.merge([operation: :delete], client_opts))
  end

  @doc """
  Delete multiple messages in bulk.

  Returns {:ok, %{deleted_count: N, failed: [ids]}}
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec bulk_delete_messages([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def bulk_delete_messages(message_ids, opts \\ []) when is_list(message_ids) do
    client_opts = extract_client_opts(opts)
    GatewayClient.post_json("/api/v1/messages/bulk_delete", %{
      message_ids: message_ids
    }, Keyword.merge([operation: :bulk_delete], client_opts))
  end

  @doc """
  Export messages to JSON or CSV.

  Returns binary file content.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec export_messages([String.t()], String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def export_messages(message_ids, format \\ "json", opts \\ [])
      when format in ["json", "csv"] do
    client_opts = extract_client_opts(opts)
    with {:ok, body} <- GatewayClient.request(:post, "/api/v1/messages/export", %{
           message_ids: message_ids,
           format: format
         }, Keyword.merge([client: :messages, operation: :export], client_opts)),
         {:ok, content} <- normalize_export_body(body) do
      {:ok, content}
    end
  end

  # Private helpers

  defp build_query_params(opts) do
    # Filter out Telemetry-specific opts
    telemetry_keys = [:tenant_id, :user_id, :request_id]
    ClientHelpers.build_query_params(Keyword.drop(opts, telemetry_keys))
  end

  defp extract_client_opts(opts) do
    [
      client: :messages,
      tenant_id: Keyword.get(opts, :tenant_id),
      user_id: Keyword.get(opts, :user_id),
      request_id: Keyword.get(opts, :request_id)
    ]
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  @doc false
  # Normalize export body to binary.
  # Req may decode JSON automatically, so we need to re-encode if needed.
  defp normalize_export_body(body) when is_binary(body), do: {:ok, body}

  defp normalize_export_body(body) when is_map(body) or is_list(body) do
    case Jason.encode(body) do
      {:ok, binary} -> {:ok, binary}
      {:error, reason} -> {:error, {:json_encode_error, reason}}
    end
  end

  defp normalize_export_body(other) do
    {:ok, to_string(other)}
  end
end

