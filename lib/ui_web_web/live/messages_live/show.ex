defmodule UiWebWeb.MessagesLive.Show do
  @moduledoc """
  LiveView for displaying a single message in detail.
  """
  use UiWebWeb, :live_view

  alias UiWeb.Services.MessagesClient
  alias UiWebWeb.GatewayErrorHelper
  import UiWebWeb.Components.CodePreview

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket
      |> assign(:page_title, "Message Details")
      |> assign(:message, nil)
      |> assign(:loading, true)
      |> assign(:error, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    socket =
      socket
      |> assign(:message_id, id)
      |> load_message()

    {:noreply, socket}
  end

  defp load_message(socket) do
    case MessagesClient.get_message(socket.assigns.message_id) do
      {:ok, message} ->
        message_id = Map.get(message, "id") || Map.get(message, :id) || socket.assigns.message_id
        socket
        |> assign(:loading, false)
        |> assign(:message, message)
        |> assign(:page_title, "Message #{message_id}")
        |> assign(:error, nil)

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)

        socket
        |> assign(:loading, false)
        |> put_flash(:error, "Failed to load message. " <> msg)
        |> push_navigate(to: ~p"/app/#{socket.assigns.tenant_id}/messages")
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case MessagesClient.delete_message(socket.assigns.message_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Message deleted successfully")
         |> push_navigate(to: ~p"/app/#{socket.assigns.tenant_id}/messages")}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, put_flash(socket, :error, "Failed to delete. " <> msg)}
    end
  end


  def format_datetime(nil), do: "—"
  def format_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, dt, _} ->
        dt
        |> DateTime.to_naive()
        |> NaiveDateTime.to_string()
        |> String.replace("T", " ")
        |> String.slice(0, 19)

      _ ->
        datetime_string
    end
  end
  def format_datetime(_), do: "—"

  def status_badge_class("pending"), do: "bg-yellow-100 text-yellow-800"
  def status_badge_class("processing"), do: "bg-blue-100 text-blue-800"
  def status_badge_class("success"), do: "bg-green-100 text-green-800"
  def status_badge_class("completed"), do: "bg-green-100 text-green-800"
  def status_badge_class("error"), do: "bg-red-100 text-red-800"
  def status_badge_class("failed"), do: "bg-red-100 text-red-800"
  def status_badge_class(_), do: "bg-gray-100 text-gray-800"
end
