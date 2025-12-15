defmodule UiWeb.Services.ClientHelpers do
  @moduledoc """
  Common helper functions for Gateway API clients.
  
  Provides:
  - Query parameter building
  - Response normalization
  - Error handling
  """

  @doc """
  Build query parameters from keyword list, filtering out nil and empty values.
  
  ## Examples
  
      iex> build_query_params([status: "active", type: nil, search: ""])
      %{status: "active"}
  """
  @spec build_query_params(keyword()) :: map()
  def build_query_params(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> v != nil and v != "" end)
    |> Map.new()
  end

  @doc """
  Normalize Gateway response to standard format.
  
  Handles:
  - Success responses: {:ok, body}
  - Error responses in body: {:ok, %{"error" => _}} -> {:error, ...}
  - HTTP errors: {:error, {:http_error, status, body}}
  - Network errors: {:error, reason}
  
  ## Examples
  
      iex> normalize_response({:ok, %{"data" => []}})
      {:ok, %{"data" => []}}
      
      iex> normalize_response({:ok, %{"error" => "Not found"}})
      {:error, %{reason: :gateway_error, details: %{"error" => "Not found"}}}
      
      iex> normalize_response({:error, {:http_error, 404, %{"error" => "Not found"}}})
      {:error, {:http_error, 404, %{"error" => "Not found"}}}
  """
  @spec normalize_response({:ok, term()} | {:error, term()}) :: {:ok, term()} | {:error, term()}
  def normalize_response({:ok, %{"error" => error_msg} = body}) when is_map(body) do
    # Only treat as error if "error" is the only key or if it's clearly an error response
    # Some valid responses may have "error" as a field (e.g., error_rate in metrics)
    if Map.has_key?(body, "error") and map_size(body) == 1 do
      {:error, %{reason: :gateway_error, details: body, message: error_msg}}
    else
      # If "error" is just one of many fields, treat as success
      {:ok, body}
    end
  end

  # Handle empty body (e.g., 204 No Content)
  def normalize_response({:ok, ""}), do: {:ok, %{}}
  def normalize_response({:ok, nil}), do: {:ok, %{}}

  def normalize_response({:ok, body}) when is_map(body) or is_list(body) do
    {:ok, body}
  end

  def normalize_response({:ok, body}) when is_binary(body) do
    # Try to decode JSON if it's a JSON string
    case Jason.decode(body) do
      {:ok, decoded} -> normalize_response({:ok, decoded})
      {:error, _} -> {:ok, body}  # Return as binary if not JSON
    end
  end

  def normalize_response({:error, reason}) do
    {:error, reason}
  end

  def normalize_response(other) do
    {:error, {:invalid_response, other}}
  end

  @doc """
  Handle delete operation response.
  
  Converts {:ok, _} to :ok, preserves errors.
  
  ## Examples
  
      iex> handle_delete_response({:ok, %{"deleted" => true}})
      :ok
      
      iex> handle_delete_response({:error, :not_found})
      {:error, :not_found}
  """
  @spec handle_delete_response({:ok, term()} | {:error, term()}) :: :ok | {:error, term()}
  def handle_delete_response({:ok, _}), do: :ok
  def handle_delete_response({:error, reason}), do: {:error, reason}

  @doc """
  Extract data from paginated response.
  
  Handles both formats:
  - %{"data" => items, "pagination" => %{...}}
  - %{"items" => items}
  - Direct list
  
  ## Examples
  
      iex> extract_items(%{"data" => [1, 2], "pagination" => %{}})
      [1, 2]
      
      iex> extract_items(%{"items" => [1, 2]})
      [1, 2]
      
      iex> extract_items([1, 2])
      [1, 2]
  """
  @spec extract_items(map() | list()) :: list()
  def extract_items(%{"data" => items}) when is_list(items), do: items
  def extract_items(%{"items" => items}) when is_list(items), do: items
  def extract_items(items) when is_list(items), do: items
  def extract_items(_), do: []
end

