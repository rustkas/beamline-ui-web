defmodule UiWebWeb.Components.GatewayStatus do
  @moduledoc """
  Gateway status badge component for displaying Gateway health with debouncing.
  """
  use Phoenix.LiveComponent

  alias UiWeb.Services.GatewayClient

  @refresh_interval :timer.seconds(10)  # UI refresh каждые 10 секунд

  @impl true
  def mount(socket) do
    if connected?(socket) do
      # Schedule periodic updates
      schedule_refresh()
    end

    {:ok, assign(socket, last_check: nil, health_status: nil)}
  end

  @impl true
  def update(assigns, socket) do
    # Get cached status (no network call)
    # cached_health_status returns map or nil, not {:ok, map}
    status = GatewayClient.cached_health_status()

    socket =
      socket
      |> assign(assigns)
      |> assign(:health_status, status)
      |> assign(:healthy, GatewayClient.healthy?())

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    # Trigger refresh (will use cache if available)
    case GatewayClient.check_health() do
      {:ok, status} ->
        schedule_refresh()
        {:noreply, assign(socket, :health_status, status)}

      {:error, _} ->
        schedule_refresh()
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("force_refresh", _params, socket) do
    # User explicit refresh
    case GatewayClient.check_health!(force: true) do
      {:ok, status} ->
        {:noreply,
         socket
         |> assign(:health_status, status)
         |> put_flash(:info, "Gateway status refreshed")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Health check failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <%= if @healthy do %>
        <span class="flex h-2 w-2 relative">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
          <span class="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
        </span>
        <span class="text-xs text-gray-600">Gateway Online</span>
      <% else %>
        <span class="flex h-2 w-2 bg-red-500 rounded-full"></span>
        <span class="text-xs text-gray-600">Gateway Offline</span>
      <% end %>

      <!-- Cache indicator -->
      <%= if @health_status && @health_status["cached_at"] do %>
        <span class="text-xs text-gray-400">
          (cached <%= time_ago(@health_status["cached_at"]) %>)
        </span>
      <% end %>

      <!-- Manual refresh button -->
      <button
        phx-click="force_refresh"
        phx-target={@myself}
        class="text-xs text-indigo-600 hover:text-indigo-900"
        title="Force refresh"
      >
        ↻
      </button>
    </div>
    """
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp time_ago(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, dt, _} -> time_ago(dt)
      _ -> "unknown"
    end
  end

  defp time_ago(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 5 -> "just now"
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      true -> "#{div(diff, 3600)}h ago"
    end
  end

  defp time_ago(_), do: "unknown"
end
