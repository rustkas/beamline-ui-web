defmodule UiWebWeb.DashboardLive do
  use UiWebWeb, :live_view

  alias UiWeb.Services.GatewayClient
  alias UiWebWeb.GatewayErrorHelper
  import UiWebWeb.DashboardComponents

  @poll_ms 5_000

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Dashboard")
      |> assign(health: %{"status" => "unknown"})
      |> assign(
        metrics: %{
          "rps" => nil,
          "latency" => %{"p50" => nil, "p95" => nil, "p99" => nil},
          "error_rate" => nil,
          "nats" => nil
        }
      )
      |> assign(components: %{})
      |> assign(error: nil)

    if connected?(socket) do
      :timer.send_interval(@poll_ms, :tick)
      send(self(), :tick)
      Phoenix.PubSub.subscribe(UiWeb.PubSub, "workers:heartbeat")
    end

    {:ok, socket}
  end

  def handle_info({:event, heartbeat}, socket) do
    worker_id = heartbeat["worker_id"] || "unknown"
    updated_workers = Map.put(socket.assigns.workers, worker_id, heartbeat)
    {:noreply, assign(socket, workers: updated_workers)}
  end

  def handle_info(:tick, socket) do
    socket =
      case GatewayClient.request(:get, "/_health", nil) do
        {:ok, json} ->
          components = extract_component_health(json)
          socket
          |> assign(health: json, error: nil)
          |> assign(components: components)

        {:error, reason} ->
          msg = GatewayErrorHelper.format_gateway_error(reason)
          assign(socket, error: "Failed to fetch Gateway health. " <> msg)
      end

    socket =
      case GatewayClient.request(:get, "/metrics", nil) do
        {:ok, metrics} -> assign(socket, metrics: normalize_metrics(metrics))
        _ -> socket
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="py-8 px-4">
      <div class="mb-6">
        <h2 class="text-3xl font-bold text-gray-900">Beamline Dashboard</h2>
        <p class="text-sm text-gray-500 mt-1">Real-time system metrics and component health</p>
      </div>

      <%= if @error do %>
        <div class="mb-4 rounded-md bg-red-50 border border-red-200 text-red-700 p-4 text-sm">
          <div class="flex items-center">
            <span class="mr-2">⚠️</span>
            <span>Failed to fetch Gateway health: <%= @error %></span>
          </div>
        </div>
      <% end %>

      <!-- Component Health Cards -->
      <div class="mb-8">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">Component Health</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <.health_card
            name="C-Gateway"
            status={get_component_status(@components, "gateway")}
            details={get_component_details(@components, "gateway")}
          />
          <.health_card
            name="Router"
            status={get_component_status(@components, "router")}
            details={get_component_details(@components, "router")}
          />
          <.health_card
            name="Worker CAF"
            status={get_component_status(@components, "worker_caf")}
            details={get_component_details(@components, "worker_caf")}
          />
          <.health_card
            name="NATS"
            status={get_nats_status(@health, @metrics)}
            details={get_nats_details(@health, @metrics)}
          />
        </div>
      </div>

      <!-- Active Workers -->
      <div class="mb-8">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">Active Workers (Real-time)</h3>
        <%= if map_size(@workers) == 0 do %>
          <p class="text-gray-500 italic">No workers active</p>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for {id, info} <- @workers do %>
              <div class="bg-white rounded-lg shadow p-4 border-l-4 border-green-500">
                <div class="flex justify-between items-start">
                  <div>
                    <h4 class="font-bold text-gray-900"><%= id %></h4>
                    <p class="text-xs text-gray-500">Last seen: <%= info["timestamp"] %></p>
                  </div>
                  <span class="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                    <%= info["status"] || "Active" %>
                  </span>
                </div>
                <div class="mt-2 text-sm text-gray-600">
                  Load: <%= info["load"] || 0.0 %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Real-time Metrics -->
      <div class="mb-8">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">Real-time Metrics</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <.metric_card
            label="Throughput"
            value={@metrics["rps"] || @metrics[:rps]}
            unit="req/s"
          />
          <.metric_card
            label="Latency (p50)"
            value={get_latency_value(@metrics, "p50")}
            unit="ms"
            subvalue={format_latency_subvalue(@metrics)}
          />
          <.metric_card
            label="Latency (p95)"
            value={get_latency_value(@metrics, "p95")}
            unit="ms"
          />
          <.metric_card
            label="Error Rate"
            value={format_error_rate(@metrics["error_rate"] || @metrics[:error_rate])}
            unit="%"
          />
        </div>
      </div>

      <!-- Additional Info -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="p-4 bg-white shadow rounded-lg">
          <h4 class="text-sm font-semibold text-gray-600 mb-2">System Status</h4>
          <p class="text-lg font-medium">
            <%= String.capitalize(@health["status"] || @health[:status] || "unknown") %>
          </p>
          <%= if @health["version"] || @health[:version] do %>
            <p class="text-sm text-gray-500 mt-1">
              Version: <%= @health["version"] || @health[:version] %>
            </p>
          <% end %>
        </div>
        <div class="p-4 bg-white shadow rounded-lg">
          <h4 class="text-sm font-semibold text-gray-600 mb-2">Last Updated</h4>
          <p class="text-lg font-medium">
            <%= format_timestamp(@health["timestamp"] || @health[:timestamp]) %>
          </p>
          <p class="text-xs text-gray-500 mt-1">Auto-refresh every 5 seconds</p>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp extract_component_health(health) do
    %{
      "gateway" => %{
        "status" => health["status"] || health[:status] || "unknown",
        "version" => health["version"] || health[:version],
        "service" => health["service"] || health[:service] || "gateway"
      },
      "router" => %{
        "status" => health["router"] && (health["router"]["status"] || health[:router][:status]) || "unknown",
        "version" => health["router"] && (health["router"]["version"] || health[:router][:version])
      },
      "worker_caf" => %{
        "status" => health["worker_caf"] && (health["worker_caf"]["status"] || health[:worker_caf][:status]) || "unknown"
      }
    }
  end

  defp get_component_status(components, key) do
    components
    |> Map.get(key, %{})
    |> Map.get("status", "unknown")
  end

  defp get_component_details(components, key) do
    component = Map.get(components, key, %{})
    version = Map.get(component, "version")
    service = Map.get(component, "service")

    cond do
      version -> "v#{version}"
      service -> String.capitalize(service)
      true -> nil
    end
  end

  defp get_nats_status(health, metrics) do
    nats = health["nats"] || health[:nats] || metrics["nats"] || metrics[:nats]

    cond do
      is_map(nats) ->
        connected = nats["connected"] || nats[:connected] || false
        if connected, do: "healthy", else: "unhealthy"

      is_binary(nats) ->
        String.downcase(nats)

      true ->
        "unknown"
    end
  end

  defp get_nats_details(_health, metrics) do
    nats = metrics["nats"] || metrics[:nats]
    if is_map(nats) && (nats["connected"] || nats[:connected]), do: "Connected", else: nil
  end

  defp normalize_metrics(metrics) when is_map(metrics) do
    # Ensure latency is a map with p50, p95, p99
    latency = metrics["latency"] || metrics[:latency] || %{}

    metrics
    |> Map.put("latency", normalize_latency(latency))
    |> Map.put("rps", metrics["rps"] || metrics[:rps])
    |> Map.put("error_rate", metrics["error_rate"] || metrics[:error_rate])
  end

  defp normalize_latency(latency) when is_map(latency) do
    %{
      "p50" => latency["p50"] || latency[:p50],
      "p95" => latency["p95"] || latency[:p95],
      "p99" => latency["p99"] || latency[:p99]
    }
  end

  defp normalize_latency(_), do: %{"p50" => nil, "p95" => nil, "p99" => nil}

  defp get_latency_value(metrics, percentile) do
    latency = metrics["latency"] || metrics[:latency] || %{}
    latency[percentile] || latency[String.to_atom(percentile)]
  end

  defp format_latency_subvalue(metrics) do
    latency = metrics["latency"] || metrics[:latency] || %{}
    p50 = latency["p50"] || latency[:p50]
    p95 = latency["p95"] || latency[:p95]

    if p50 && p95 do
      "p50: #{format_number(p50)}ms / p95: #{format_number(p95)}ms"
    else
      nil
    end
  end

  defp format_error_rate(nil), do: nil
  defp format_error_rate(rate) when is_number(rate) do
    :erlang.float_to_binary(rate * 100, decimals: 2)
  end
  defp format_error_rate(rate), do: rate

  defp format_number(nil), do: "-"
  defp format_number(num) when is_number(num) do
    # Convert to float for formatting
    float_num = num * 1.0
    :erlang.float_to_binary(float_num, decimals: 2)
  end
  defp format_number(val), do: to_string(val)

  defp format_timestamp(nil), do: "Never"
  defp format_timestamp(ts) when is_integer(ts) do
    ts
    |> DateTime.from_unix!(:millisecond)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end
  defp format_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
      _ -> ts
    end
  end
  defp format_timestamp(_), do: "-"
end
