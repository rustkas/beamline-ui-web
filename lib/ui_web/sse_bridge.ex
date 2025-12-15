defmodule UiWeb.SSEBridge do
  @moduledoc false
  use GenServer
  require Logger

  alias UiWebWeb.Endpoint

  @default_tenant "tenant_dev"
  @default_gateway "http://localhost:8081"
  @path "/api/v1/messages/stream"

  # Public API
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # GenServer
  @impl true
  def init(_opts) do
    state = %{
      tenant: tenant(),
      gateway: gateway_url(),
      backoff_ms: 1000
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    url = state.gateway <> @path <> "?tenant_id=" <> state.tenant
    Logger.info("SSEBridge connecting to #{url}")
    append_log("SSEBridge connecting to #{url}")

    case do_connect(url) do
      :ok ->
        {:noreply, %{state | backoff_ms: 1000}}

      {:error, reason} ->
        Logger.warning(
          "SSEBridge connect error: #{inspect(reason)}; retry in #{state.backoff_ms} ms"
        )

        Process.send_after(self(), :connect, state.backoff_ms)
        {:noreply, %{state | backoff_ms: next_backoff(state.backoff_ms)}}
    end
  end

  defp tenant do
    Application.get_env(:ui_web, :tenant_id, @default_tenant)
  end

  defp gateway_url do
    cfg = Application.get_env(:ui_web, :gateway, [])
    Keyword.get(cfg, :url, @default_gateway)
  end

  # Mint-based SSE stream
  defp do_connect(url) do
    uri = URI.parse(url)
    scheme = (uri.scheme || "http") |> String.to_atom()
    host = uri.host
    port = uri.port || if scheme == :https, do: 443, else: 80
    path = uri.path <> if uri.query, do: "?" <> uri.query, else: ""

    with {:ok, conn} <- Mint.HTTP.connect(scheme, host, port, []),
         {:ok, conn, ref} <- Mint.HTTP.request(conn, "GET", path, headers(host), ""),
         {:ok, conn} <- Mint.HTTP.set_mode(conn, :passive) do
      loop(conn, ref, %{event: nil, data: []}, host)
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  defp headers(host) do
    [
      {"host", host},
      {"accept", "text/event-stream"},
      {"cache-control", "no-cache"},
      {"connection", "keep-alive"},
      {"user-agent", "ui_web/sse_bridge"}
    ]
  end

  defp loop(conn, ref, acc, host) do
    case Mint.HTTP.recv(conn, 0, 30_000) do
      {:ok, conn, messages} ->
        {conn, ref, acc} = handle_responses(conn, ref, acc, messages)
        loop(conn, ref, acc, host)

      {:error, _conn, reason} ->
        {:error, reason}

      other ->
        {:error, other}
    end
  end

  defp handle_responses(conn, ref, acc, []), do: {conn, ref, acc}

  defp handle_responses(conn, ref, acc, [msg | rest]) do
    {conn, ref, acc} = handle_response(conn, ref, acc, msg)
    handle_responses(conn, ref, acc, rest)
  end

  defp handle_response(conn, ref, acc, {:status, _, 200}), do: {conn, ref, acc}
  defp handle_response(conn, ref, acc, {:headers, _, _headers}), do: {conn, ref, acc}

  defp handle_response(conn, ref, acc, {:data, _, chunk}) do
    # SSE lines separated by \n; may come partial
    acc = process_chunk(acc, chunk)
    {conn, ref, acc}
  end

  defp handle_response(conn, ref, acc, {:done, _}), do: {conn, ref, acc}
  defp handle_response(conn, ref, acc, _), do: {conn, ref, acc}

  defp process_chunk(acc, chunk) do
    lines = String.split(chunk, "\n")

    Enum.reduce(lines, acc, fn line, st ->
      cond do
        String.starts_with?(line, "event:") ->
          %{st | event: String.trim_leading(String.trim(line), "event:") |> String.trim()}

        String.starts_with?(line, "data:") ->
          data = String.trim_leading(String.trim(line), "data:") |> String.trim()
          %{st | data: [data | st.data]}

        String.trim(line) == "" ->
          dispatch(st)
          %{event: nil, data: []}

        true ->
          st
      end
    end)
  end

  defp dispatch(%{event: nil}), do: :ok

  defp dispatch(%{event: event, data: data_lines}) do
    payload = Enum.reverse(data_lines) |> Enum.join("\n")

    decoded =
      case Jason.decode(payload) do
        {:ok, map} -> map
        _ -> %{"raw" => payload}
      end

    # Broadcast to messages:{tenant}
    topic = "messages:" <> tenant()
    Logger.info("SSEBridge broadcast topic=#{topic} event=#{event}")
    append_log("SSEBridge broadcast topic=#{topic} event=#{event}")
    Endpoint.broadcast!(topic, "message_event", %{"event" => event, "data" => decoded})
  end

  defp next_backoff(ms) do
    ms2 = ms * 2
    if ms2 > 30_000, do: 30_000, else: ms2
  end

  defp append_log(line) when is_binary(line) do
    path = System.get_env("UIWEB_SSE_LOG") || "/tmp/ui_web_sse.log"
    # Best-effort append; ignore errors to avoid crashing the bridge
    _ = :file.write_file(String.to_charlist(path), String.to_charlist(line <> "\n"), [:append])
    :ok
  end
end
