defmodule UiWeb.Services.GatewayClient do
  @moduledoc """
  HTTP client for C-Gateway API with fallback strategies.

  Features:
  - Environment-based configuration
  - Automatic retry with exponential backoff
  - Circuit breaker pattern
  - Health check monitoring
  - Mock fallback for development
  """

  require Logger
  use GenServer

  alias UiWeb.Services.ClientHelpers

  @base_url Application.compile_env(:ui_web, [:gateway, :url], "http://localhost:8081")
  @timeout Application.compile_env(:ui_web, [:gateway, :timeout], 10_000)
  @retry_attempts Application.compile_env(:ui_web, [:gateway, :retry_attempts], 3)
  @health_check_interval Application.compile_env(:ui_web, [:gateway, :health_check_interval], 30_000)
  @health_cache_ttl :timer.seconds(5)  # Кэш на 5 секунд
  @health_cache_key :gateway_health_status

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Start periodic health checks
    schedule_health_check()

    {:ok, %{
      healthy: true,
      last_check: DateTime.utc_now(),
      consecutive_failures: 0
    }}
  end

  def handle_info(:health_check, state) do
    # Background check bypasses cache to get fresh status
    case perform_health_check() do
      {:commit, {:ok, _}, _} ->
        schedule_health_check()
        {:noreply, %{state | healthy: true, consecutive_failures: 0, last_check: DateTime.utc_now()}}

      {:commit, {:error, _}, _} ->
        failures = state.consecutive_failures + 1
        Logger.warning("Gateway health check failed (#{failures} consecutive)")

        schedule_health_check()
        {:noreply, %{state | healthy: failures < 3, consecutive_failures: failures, last_check: DateTime.utc_now()}}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Public API

  @doc """
  Check if Gateway is healthy.
  """
  def healthy? do
    case Process.whereis(__MODULE__) do
      nil ->
        # If GenServer not started, try direct check
        case check_health() do
          {:ok, _} -> true
          {:error, _} -> false
        end
      pid ->
        try do
          state = :sys.get_state(pid)
          Map.get(state, :healthy, false)
        rescue
          _ -> false
        end
    end
  end

  @doc """
  Check Gateway health with caching.

  Response is cached for 5 seconds to prevent excessive requests.
  Multiple concurrent calls will be deduplicated.

  ## Examples

      iex> GatewayClient.check_health()
      {:ok, %{"status" => "ok", "timestamp" => "...", "cached_at" => "..."}}

      # Second call within 5 seconds returns cached result
      iex> GatewayClient.check_health()
      {:ok, %{"status" => "ok", "timestamp" => "...", "cached_at" => "..."}}  # from cache
  """
  def check_health do
    Cachex.fetch(:gateway_cache, @health_cache_key, fn ->
      # This function only executes if cache miss
      # Multiple concurrent calls will be deduplicated
      perform_health_check()
    end)
    |> handle_cache_result()
    |> tap(fn result ->
      # Emit cache hit telemetry for cached results
      # Note: perform_health_check already emits :health_check telemetry when cache miss,
      # so we only emit here for cache hits (when result comes from cache, not from perform_health_check)
      # We detect cache hit by checking if the result has "cached_at" and cache still has the value
      case result do
        {:ok, %{"cached_at" => _}} ->
          # Check if this is really from cache (not fresh from perform_health_check)
          # by verifying cache still has the value
          case Cachex.exists?(:gateway_cache, @health_cache_key) do
            {:ok, true} ->
              # This is a cached result, emit cache hit telemetry
              :telemetry.execute(
                [:ui_web, :gateway, :health_check],
                %{duration: 0, count: 1},
                %{result: :cache_hit}
              )
            _ ->
              :ok
          end
        _ ->
          :ok
      end
    end)
  end

  @doc """
  Force health check bypass cache.

  Use only for explicit user-triggered checks.
  """
  def check_health!(force: true) do
    Cachex.del(:gateway_cache, @health_cache_key)
    check_health()
  end

  @doc """
  Get cached health status without triggering new check.
  Returns nil if cache is empty.
  """
  def cached_health_status do
    case Cachex.get(:gateway_cache, @health_cache_key) do
      {:ok, nil} -> nil
      {:ok, result} -> result
      _ -> nil
    end
  end

  @doc """
  Generic request wrapper with retry and fallback.

  ## Options

  - `:client` - Client identifier (:messages, :extensions, :policies, :dashboard)
  - `:operation` - Operation type (:list, :get, :create, :update, :delete, :export)
  - `:tenant_id` - Tenant identifier
  - `:user_id` - User identifier
  - `:request_id` - Request ID (from Logger.metadata if not provided)
  - `:params` - Query parameters (for GET requests)
  """
  def request(method, path, body \\ nil, opts \\ []) do
    if use_mock?() do
      mock_request(method, path, body, opts)
    else
      real_request(method, path, body, opts)
    end
  end

  # Convenience methods for backward compatibility
  def get_json(path, opts \\ []) do
    # Extract operation from path if not provided
    opts = Keyword.put_new(opts, :operation, infer_operation(:get, path))
    request(:get, path, nil, opts)
  end

  def post_json(path, body, opts \\ []) do
    opts = Keyword.put_new(opts, :operation, infer_operation(:post, path))
    request(:post, path, body, opts)
  end

  def put_json(path, body, opts \\ []) do
    opts = Keyword.put_new(opts, :operation, infer_operation(:put, path))
    request(:put, path, body, opts)
  end

  def delete(path, opts \\ []) do
    opts = Keyword.put_new(opts, :operation, infer_operation(:delete, path))
    case request(:delete, path, nil, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Implementation

  defp real_request(method, path, body, opts) do
    start = System.monotonic_time()
    url = "#{@base_url}#{path}"

    # Extract context from opts for Telemetry
    client = Keyword.get(opts, :client, :unknown)
    operation = Keyword.get(opts, :operation, :unknown)
    tenant_id = Keyword.get(opts, :tenant_id)
    user_id = Keyword.get(opts, :user_id)
    request_id = Keyword.get(opts, :request_id) || Logger.metadata()[:request_id]

    # Extract query params for metadata
    query = extract_query_params(opts)

    # Emit client request event
    request_metadata = %{
      client: client,
      operation: operation,
      method: method,
      url: path,
      query: query,
      tenant_id: tenant_id,
      user_id: user_id,
      request_id: request_id
    }

    :telemetry.execute(
      [:ui_web, :client, :request],
      %{},
      request_metadata
    )

    req_opts = [
      method: method,
      url: url,
      retry: :transient,
      max_retries: @retry_attempts,
      retry_delay: &exp_backoff/1,
      receive_timeout: @timeout
    ]

    req_opts =
      if body do
        Keyword.put(req_opts, :json, body)
      else
        req_opts
      end

    req_opts = Keyword.merge(req_opts, opts)

    result =
      case Req.request(req_opts) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          # Normalize response (check for errors in body, handle JSON decoding)
          ClientHelpers.normalize_response({:ok, body})

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("Gateway error: status=#{status} body=#{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("Gateway network error: #{inspect(reason)}")
          {:error, reason}
      end

    duration = System.monotonic_time() - start

    # Classify result for response metadata
    {status, error_reason, success} = classify_result_for_response(result, opts)

    # Emit client response event
    response_metadata = Map.merge(request_metadata, %{
      status: status,
      success: success,
      error_reason: error_reason
    })

    :telemetry.execute(
      [:ui_web, :client, :response],
      %{duration: duration},
      response_metadata
    )

    # Also emit legacy gateway event for backward compatibility
    measurements = %{duration: duration}
    legacy_metadata = %{
      method: method,
      path: normalize_path(path),
      base_url: @base_url,
      result: classify_result(result)
    }

    :telemetry.execute([:ui_web, :gateway, :request], measurements, legacy_metadata)

    result
  end

  defp extract_query_params(opts) do
    case Keyword.get(opts, :params) do
      nil -> %{}
      params when is_map(params) -> params
      params when is_list(params) -> Map.new(params)
      _ -> %{}
    end
  end

  defp classify_result_for_response({:ok, _}, _opts), do: {200, nil, true}
  defp classify_result_for_response({:error, {:http_error, status, _}}, _opts) when is_integer(status), do: {status, :gateway_error, false}
  defp classify_result_for_response({:error, %{reason: reason}}, _opts), do: {500, reason, false}
  defp classify_result_for_response({:error, %Req.TransportError{reason: :timeout}}, _opts), do: {500, :timeout, false}
  defp classify_result_for_response({:error, _reason}, _opts), do: {500, :unknown_error, false}

  defp normalize_path(path) do
    # Remove query string if present
    String.split(path, "?") |> hd()
  end

  defp classify_result({:ok, _}), do: :ok
  defp classify_result({:error, {:http_error, status, _}}) when status in 400..499, do: :client_error
  defp classify_result({:error, {:http_error, status, _}}) when status in 500..599, do: :server_error
  defp classify_result({:error, %{reason: :timeout}}), do: :timeout
  defp classify_result({:error, %Req.TransportError{reason: :timeout}}), do: :timeout
  defp classify_result({:error, _}), do: :error

  defp mock_request(method, path, body, opts \\ []) do
    start = System.monotonic_time()
    Logger.debug("Mock Gateway: #{method} #{path}")
    # Fallback to test mock server
    mock_url = "http://localhost:8082#{path}"

    # Extract context from opts for Telemetry
    client = Keyword.get(opts, :client, :unknown)
    operation = Keyword.get(opts, :operation, :unknown)
    tenant_id = Keyword.get(opts, :tenant_id)
    user_id = Keyword.get(opts, :user_id)
    request_id = Keyword.get(opts, :request_id) || Logger.metadata()[:request_id]

    # Extract query params for metadata
    query = extract_query_params(opts)

    # Emit client request event
    request_metadata = %{
      client: client,
      operation: operation,
      method: method,
      url: path,
      query: query,
      tenant_id: tenant_id,
      user_id: user_id,
      request_id: request_id
    }

    :telemetry.execute(
      [:ui_web, :client, :request],
      %{},
      request_metadata
    )

    # For export endpoints, we need to return binary content, not decoded JSON
    is_export = String.contains?(path, "/export")

    req_opts = [
      method: method,
      url: mock_url,
      receive_timeout: 5_000
    ]

    req_opts =
      if is_export do
        # For export, don't decode JSON automatically - we need binary
        # Disable all automatic decoding
        req_opts
        |> Keyword.put(:decode_body, false)
        |> Keyword.put(:decode_json, false)
        |> Keyword.put(:raw, true)  # Request raw body
        |> then(fn opts ->
          if body do
            Keyword.put(opts, :body, Jason.encode!(body))
            |> Keyword.put(:headers, [{"content-type", "application/json"}])
          else
            opts
          end
        end)
      else
        if body do
          Keyword.put(req_opts, :json, body)
        else
          req_opts
        end
      end

    result =
      Req.request(req_opts)
      |> case do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          # For export endpoints, return binary content as-is
          # Always check if body needs to be re-encoded (Req may decode JSON automatically)
          if is_export do
            # Ensure body is binary, not decoded map/list
            # Req may decode JSON automatically, so we need to re-encode if needed
            binary_body = cond do
              is_binary(body) -> body
              is_list(body) -> Jason.encode!(body)  # Re-encode if decoded list
              is_map(body) -> Jason.encode!(body)  # Re-encode if decoded map
              true -> to_string(body)
            end
            {:ok, binary_body}
          else
            # For other endpoints, decode JSON if it's a string
            decoded_body = case body do
              body when is_binary(body) ->
                case Jason.decode(body) do
                  {:ok, decoded} -> decoded
                  {:error, _} -> body
                end
              body when is_map(body) -> body
              body -> body
            end
            {:ok, decoded_body}
          end

        {:ok, %Req.Response{status: status, body: body}} ->
          # Always decode JSON body if it's a string (for error responses)
          decoded_body = case body do
            body when is_binary(body) ->
              case Jason.decode(body) do
                {:ok, decoded} -> decoded
                {:error, _} -> body
              end
            body when is_map(body) -> body
            body -> body
          end
          {:error, {:http_error, status, decoded_body}}

        {:error, _} = error ->
          error
      end

    duration = System.monotonic_time() - start

    # Classify result for response metadata
    {status, error_reason, success} = classify_result_for_response(result, opts)

    # Emit client response event
    response_metadata = Map.merge(request_metadata, %{
      status: status,
      success: success,
      error_reason: error_reason
    })

    :telemetry.execute(
      [:ui_web, :client, :response],
      %{duration: duration},
      response_metadata
    )

    # Also emit legacy gateway event for backward compatibility
    measurements = %{duration: duration}
    legacy_metadata = %{
      method: method,
      path: normalize_path(path),
      base_url: "http://localhost:8082",
      result: classify_result(result)
    }

    :telemetry.execute([:ui_web, :gateway, :request], measurements, legacy_metadata)

    result
  end

  defp exp_backoff(attempt) do
    trunc(:math.pow(2, attempt) * 1000)
  end

  defp use_mock? do
    Application.get_env(:ui_web, :features, [])
    |> Keyword.get(:use_mock_gateway, false)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end

  # Private Implementation for Health Check

  defp perform_health_check do
    start_time = System.monotonic_time()

    result =
      case request(:get, "/_health", nil, receive_timeout: 3_000) do
        {:ok, body} ->
          # Return map, not {:ok, map} - Cachex.fetch will wrap it
          Map.put(body, "cached_at", DateTime.utc_now() |> DateTime.to_iso8601())

        {:error, reason} ->
          Logger.warning("Health check failed: #{inspect(reason)}")
          {:error, reason}
      end

    duration = System.monotonic_time() - start_time

    measurements = %{duration: duration}
    metadata = %{
      result: case result do
        %{} = _map -> :ok  # Success - result is a map
        {:error, :timeout} -> :timeout
        {:error, _} -> :error
      end
    }

    :telemetry.execute([:ui_web, :gateway, :health_check], measurements, metadata)

    # Return with TTL - result is already a map (not {:ok, map})
    {:commit, result, ttl: @health_cache_ttl}
  end

  defp handle_cache_result({:ok, result}), do: result
  defp handle_cache_result({:commit, result, _opts}), do: result
  defp handle_cache_result({:error, reason}), do: {:error, reason}

  # Infer operation from path and method
  defp infer_operation(:get, path) do
    cond do
      String.contains?(path, "/bulk") -> :bulk_get
      Regex.match?(~r{/\d+$}, path) -> :get
      true -> :list
    end
  end

  defp infer_operation(:post, path) do
    cond do
      String.contains?(path, "/bulk") -> :bulk_delete
      String.contains?(path, "/export") -> :export
      true -> :create
    end
  end

  defp infer_operation(:put, _path), do: :update

  defp infer_operation(:patch, path) do
    if String.contains?(path, "/toggle"), do: :toggle, else: :update
  end

  defp infer_operation(:delete, _path), do: :delete
  defp infer_operation(_method, _path), do: :unknown
end
