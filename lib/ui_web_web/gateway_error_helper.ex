defmodule UiWebWeb.GatewayErrorHelper do
  @moduledoc """
  Helpers for formatting Gateway-related errors for UI.

  Provides a unified way to format Gateway errors into user-friendly messages,
  avoiding technical details leaking into the UI.
  """

  alias UiWeb.Services.GatewayClient

  @doc """
  Formats a Gateway error into a user-friendly message.

  ## Examples

      iex> format_gateway_error({:http_error, 500, %{}})
      "Gateway is temporarily unavailable (HTTP 500). Please try again later."

      iex> format_gateway_error(:timeout)
      "Gateway did not respond in time (timeout)."

      iex> format_gateway_error(:econnrefused)
      "Connection to Gateway was refused. Please ensure C-Gateway is running (default: http://localhost:8081)."
  """
  @spec format_gateway_error(term()) :: String.t()
  def format_gateway_error({:http_error, status, _body}) when status in 500..599 do
    "Gateway is temporarily unavailable (HTTP #{status}). Please try again later."
  end

  def format_gateway_error({:http_error, 404, _body}) do
    "Resource not found in Gateway (404). It may have been deleted or never existed."
  end

  def format_gateway_error({:http_error, 429, _body}) do
    "Gateway is rate limiting requests. Please try again in a moment."
  end

  def format_gateway_error({:http_error, status, _body}) when status in 400..499 do
    "Gateway request failed with HTTP #{status}. Please check your input and try again."
  end

  def format_gateway_error({:http_error, status, _body}) do
    "Gateway request failed with HTTP #{status}."
  end

  def format_gateway_error(:timeout) do
    "Gateway did not respond in time (timeout). Please try again later."
  end

  def format_gateway_error(:nxdomain) do
    "Gateway host name could not be resolved. Please check your Gateway URL configuration."
  end

  def format_gateway_error(:econnrefused) do
    "Connection to Gateway was refused. Please ensure C-Gateway is running (default: http://localhost:8081)."
  end

  def format_gateway_error(:enotfound) do
    "Gateway host not found. Please check your Gateway URL configuration."
  end

  def format_gateway_error({:req, %{reason: reason}}) do
    format_gateway_error(reason)
  end

  # Handle normalized Gateway errors from ClientHelpers.normalize_response
  def format_gateway_error(%{reason: :gateway_error, message: message}) when is_binary(message) do
    "Gateway error: #{message}"
  end

  def format_gateway_error(%{reason: :gateway_error, details: %{"error" => error_msg}}) when is_binary(error_msg) do
    "Gateway error: #{error_msg}"
  end

  def format_gateway_error(%{reason: :gateway_error}) do
    "Gateway returned an error. Please try again later."
  end

  # Handle Req structs - use pattern matching on map keys to avoid compile-time dependency
  def format_gateway_error(%{__struct__: Req.TransportError} = error) do
    case Map.get(error, :reason) do
      nil -> format_gateway_error(:unknown)
      reason -> format_gateway_error(reason)
    end
  end

  def format_gateway_error(%{__struct__: Req.Error} = error) do
    case Map.get(error, :reason) do
      nil -> format_gateway_error(:unknown)
      reason -> format_gateway_error(reason)
    end
  end

  def format_gateway_error(other) when is_atom(other) do
    # For other atoms (like :enoent, :eacces, etc.), provide a generic message
    base_msg = "Gateway request failed."

    # Optionally check Gateway health status
    if GatewayClient.healthy?() do
      base_msg
    else
      base_msg <> " Gateway is currently marked as unhealthy."
    end
  end

  def format_gateway_error(other) do
    # Fallback for unexpected error formats - log details but show generic message
    require Logger
    Logger.warning("Unexpected Gateway error format: #{inspect(other)}")

    base_msg = "Unexpected Gateway error occurred."

    if GatewayClient.healthy?() do
      base_msg
    else
      base_msg <> " Gateway is currently marked as unhealthy."
    end
  end
end
