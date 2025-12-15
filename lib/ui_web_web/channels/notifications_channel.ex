defmodule UiWebWeb.NotificationsChannel do
  use UiWebWeb, :channel

  @impl true
  def join("notifications:" <> _tenant = _topic, _payload, socket) do
    # CP1: allow any connect; in CP2 derive/verify tenant
    {:ok, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  @impl true
  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end
end
