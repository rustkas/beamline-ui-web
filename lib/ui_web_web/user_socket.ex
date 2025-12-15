defmodule UiWebWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "messages:*", UiWebWeb.MessagesChannel
  channel "notifications:*", UiWebWeb.NotificationsChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # CP1: no auth. In CP2+, derive tenant/scope from session or token and assign.
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
