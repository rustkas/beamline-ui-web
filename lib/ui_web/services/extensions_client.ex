defmodule UiWeb.Services.ExtensionsClient do
  @moduledoc """
  HTTP client for Extensions Registry API.

  Provides:
  - list_extensions/1 - List all extensions with filters
  - toggle_extension/2 - Enable/Disable extension
  - delete_extension/1 - Delete extension
  """

  require Logger

  alias UiWeb.Services.GatewayClient
  alias UiWeb.Services.ClientHelpers

  # Public API

  @doc """
  List extensions with optional filters.

  ## Options
    * `:type` - Filter by type (pre/validator/post/provider)
    * `:status` - Filter by status (enabled/disabled/all)
    * `:limit` - Pagination limit (default: 20)
    * `:offset` - Pagination offset (default: 0)
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)

  ## Examples
      iex> list_extensions(type: "provider", status: "enabled")
      {:ok, %{"data" => [...], "pagination" => %{"total" => 10}}}
  """
  @spec list_extensions(keyword()) :: {:ok, map()} | {:error, term()}
  def list_extensions(opts \\ []) do
    query_params = build_query_params(opts)
    client_opts = extract_client_opts(opts)
    GatewayClient.get_json("/api/v1/extensions", Keyword.merge([params: query_params, operation: :list], client_opts))
  end

  @doc """
  Toggle extension enabled/disabled state.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec toggle_extension(String.t(), boolean(), keyword()) :: {:ok, map()} | {:error, term()}
  def toggle_extension(extension_id, enabled, opts \\ []) when is_boolean(enabled) do
    client_opts = extract_client_opts(opts)
    GatewayClient.request(:patch, "/api/v1/extensions/#{extension_id}", %{enabled: enabled}, 
      Keyword.merge([client: :extensions, operation: :toggle], client_opts))
  end

  @doc """
  Delete extension from registry.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec delete_extension(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_extension(extension_id, opts \\ []) do
    client_opts = extract_client_opts(opts)
    GatewayClient.delete("/api/v1/extensions/#{extension_id}", client_opts)
  end

  @doc """
  Create new extension.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec create_extension(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_extension(attrs, opts \\ []) do
    client_opts = extract_client_opts(opts)
    GatewayClient.post_json("/api/v1/extensions", attrs, Keyword.merge([operation: :create, retry: false], client_opts))
  end

  @doc """
  Get single extension for editing.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec get_extension(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_extension(extension_id, opts \\ []) do
    client_opts = extract_client_opts(opts)
    GatewayClient.get_json("/api/v1/extensions/#{extension_id}", Keyword.merge([operation: :get], client_opts))
  end

  @doc """
  Update existing extension.
  
  ## Options
    * `:tenant_id` - Tenant identifier (for Telemetry)
    * `:user_id` - User identifier (for Telemetry)
    * `:request_id` - Request ID (for Telemetry)
  """
  @spec update_extension(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update_extension(extension_id, attrs, opts \\ []) do
    client_opts = extract_client_opts(opts)
    GatewayClient.put_json("/api/v1/extensions/#{extension_id}", attrs, Keyword.merge([operation: :update, retry: false], client_opts))
  end

  # Private helpers

  defp build_query_params(opts) do
    # Filter out Telemetry-specific opts
    telemetry_keys = [:tenant_id, :user_id, :request_id]
    ClientHelpers.build_query_params(Keyword.drop(opts, telemetry_keys))
  end

  defp extract_client_opts(opts) do
    [
      client: :extensions,
      tenant_id: Keyword.get(opts, :tenant_id),
      user_id: Keyword.get(opts, :user_id),
      request_id: Keyword.get(opts, :request_id)
    ]
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end
end

