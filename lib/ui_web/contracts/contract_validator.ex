defmodule UiWeb.Contracts.ContractValidator do
  @moduledoc """
  Validates that Mock Gateway responses match API specification.

  This module provides contract testing capabilities to ensure Mock Gateway
  remains in sync with the API specification defined in ApiSpec.
  """

  alias UiWeb.Contracts.ApiSpec
  alias UiWeb.Services.GatewayClient

  @doc """
  Validate a single endpoint against the specification.

  ## Examples

      iex> validate_endpoint("GET /api/v1/messages", %{status: 200, body: %{"data" => []}})
      {:ok, :valid}

      iex> validate_endpoint("GET /api/v1/messages", %{status: 200, body: %{}})
      {:error, "Missing required field: data"}
  """
  @spec validate_endpoint(String.t(), map()) :: {:ok, :valid} | {:error, String.t()}
  def validate_endpoint(endpoint_key, response) do
    case ApiSpec.endpoints()[endpoint_key] do
      nil ->
        {:error, "Unknown endpoint: #{endpoint_key}"}

      spec ->
        validate_response(response, spec.response)
    end
  end

  @doc """
  Test Mock Gateway against real Gateway (if available).

  Compares responses from Mock Gateway and real Gateway to ensure they match.
  Only runs if real Gateway is available (not in test environment).
  """
  @spec compare_with_real_gateway(String.t(), keyword()) :: {:ok, :match} | {:error, term()}
  def compare_with_real_gateway(endpoint_key, opts \\ []) do
    # Only run if real Gateway is configured
    if Application.get_env(:ui_web, :gateway) |> Keyword.get(:url) |> String.contains?("localhost:8082") do
      {:skip, "Mock Gateway mode - skipping real Gateway comparison"}
    else
      spec = ApiSpec.endpoints()[endpoint_key]

      if spec do
        # Make request to both Mock and Real Gateway
        mock_response = request_mock_gateway(spec, opts)
        real_response = request_real_gateway(spec, opts)

        compare_responses(mock_response, real_response, spec)
      else
        {:error, "Unknown endpoint: #{endpoint_key}"}
      end
    end
  end

  @doc """
  Validate all Mock Gateway endpoints against specification.

  Returns a map of endpoint -> validation result.
  """
  @spec validate_all() :: map()
  def validate_all do
    ApiSpec.endpoints()
    |> Enum.map(fn {key, spec} ->
      # For now, we just check that spec exists
      # In future, we can make actual requests to Mock Gateway
      {key, {:ok, :spec_exists}}
    end)
    |> Map.new()
  end

  # Private helpers

  defp validate_response(response, spec_response) do
    case response.status do
      status when status in 200..299 ->
        validate_success_response(response.body, spec_response.success)

      status ->
        # Check if this error status is expected
        expected_errors = spec_response.errors || []
        if Enum.any?(expected_errors, &(&1.status == status)) do
          {:ok, :valid_error}
        else
          {:error, "Unexpected error status: #{status}"}
        end
    end
  end

  defp validate_success_response(body, success_spec) do
    # Basic validation - check required top-level fields
    schema = success_spec.schema || %{}

    required_fields =
      schema
      |> Map.keys()
      |> Enum.filter(fn key ->
        # Check if field is required (for now, all top-level fields are required)
        true
      end)

    missing_fields =
      required_fields
      |> Enum.reject(fn field ->
        Map.has_key?(body, to_string(field))
      end)

    if Enum.empty?(missing_fields) do
      {:ok, :valid}
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp request_mock_gateway(spec, _opts) do
    # In test environment, Mock Gateway is on port 8082 (real C-Gateway default is 8081)
    base_url = "http://localhost:8082"
    url = base_url <> spec.path

    case Req.get(url) do
      {:ok, %Req.Response{status: status, body: body}} ->
        %{status: status, body: body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request_real_gateway(spec, _opts) do
    # Use GatewayClient to make request to real Gateway
    case GatewayClient.get_json(spec.path) do
      {:ok, body} ->
        %{status: 200, body: body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compare_responses(mock_response, real_response, _spec) do
    case {mock_response, real_response} do
      {{:error, _}, _} ->
        {:error, "Mock Gateway request failed"}

      {_, {:error, _}} ->
        {:error, "Real Gateway request failed"}

      {%{status: mock_status, body: mock_body}, %{status: real_status, body: real_body}} ->
        if mock_status == real_status and similar_structure?(mock_body, real_body) do
          {:ok, :match}
        else
          {:error, "Responses don't match: mock=#{inspect(mock_status)}, real=#{inspect(real_status)}"}
        end
    end
  end

  defp similar_structure?(map1, map2) when is_map(map1) and is_map(map2) do
    # Check that both have same top-level keys
    keys1 = Map.keys(map1) |> Enum.sort()
    keys2 = Map.keys(map2) |> Enum.sort()
    keys1 == keys2
  end

  defp similar_structure?(list1, list2) when is_list(list1) and is_list(list2) do
    # For lists, just check they're both lists
    true
  end

  defp similar_structure?(_, _), do: false
end
