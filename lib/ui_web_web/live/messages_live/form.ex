defmodule UiWebWeb.MessagesLive.Form do
  @moduledoc """
  LiveView for creating and editing messages.
  """
  use UiWebWeb, :live_view

  import Ecto.Changeset, only: [get_field: 2, get_field: 3, traverse_errors: 2]

  alias UiWeb.Schemas.MessageForm
  alias UiWeb.Services.MessagesClient
  alias UiWebWeb.GatewayErrorHelper

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New Message")
     |> assign(:mode, :new)
     |> assign(:message_id, nil)
     |> assign(:changeset, MessageForm.changeset(%MessageForm{}, %{}))}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    # Edit mode
    case MessagesClient.get_message(id) do
      {:ok, message} ->
        form = MessageForm.from_api(message)

        {:noreply,
         socket
         |> assign(:mode, :edit)
         |> assign(:message_id, id)
         |> assign(:page_title, "Edit Message #{id}")
         |> assign(:changeset, MessageForm.changeset(form, %{}))}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)

        {:noreply,
         socket
         |> put_flash(:error, "Failed to load message. " <> msg)
         |> push_navigate(to: ~p"/app/#{socket.assigns.tenant_id}/messages")}
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"message" => params}, socket) do
    changeset =
      %MessageForm{}
      |> MessageForm.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"message" => params}, socket) do
    changeset = MessageForm.changeset(%MessageForm{}, params)

    if changeset.valid? do
      form = Ecto.Changeset.apply_changes(changeset)
      payload = MessageForm.to_api_params(form)

      result =
        case socket.assigns.mode do
          :new -> MessagesClient.create_message(payload)
          :edit -> MessagesClient.update_message(socket.assigns.message_id, payload)
        end

      case result do
        {:ok, message} ->
          msg_text =
            case socket.assigns.mode do
              :new -> "Message created successfully"
              :edit -> "Message updated successfully"
            end

          message_id = message["id"] || message[:id] || socket.assigns.message_id

          {:noreply,
           socket
           |> put_flash(:info, msg_text)
           |> push_navigate(to: ~p"/app/#{socket.assigns.tenant_id}/messages/#{message_id}")}

        {:error, reason} ->
          msg = GatewayErrorHelper.format_gateway_error(reason)

          {:noreply,
           socket
           |> put_flash(:error, "Failed to save message. " <> msg)
           |> assign(:changeset, %{changeset | action: :insert})}
      end
    else
      {:noreply, assign(socket, :changeset, %{changeset | action: :insert})}
    end
  end
end
