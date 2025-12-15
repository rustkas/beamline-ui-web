defmodule UiWebWeb.MessagesChannel do
  use UiWebWeb, :channel

  @impl true
  def join("messages:" <> _tenant = _topic, _payload, socket) do
    # CP1: allow any connect; in CP2 derive/verify tenant from session/token
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
