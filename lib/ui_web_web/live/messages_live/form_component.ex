defmodule UiWebWeb.MessagesLive.FormComponent do
  @moduledoc """
  LiveComponent for creating and editing messages.
  """
  use UiWebWeb, :live_component

  alias UiWeb.Services.MessagesClient
  alias UiWeb.Schemas.Message
  alias UiWebWeb.GatewayErrorHelper

  def mount(socket) do
    {:ok, socket}
  end

  def update(%{message: message} = assigns, socket) when not is_nil(message) do
    changeset = Message.changeset(%Message{}, message)

    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, changeset)
      |> assign(:saving, false)

    {:ok, socket}
  end

  def update(assigns, socket) do
    changeset = Message.new_changeset()

    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, changeset)
      |> assign(:saving, false)

    {:ok, socket}
  end

  def handle_event("validate", %{"message" => message_params}, socket) do
    changeset =
      %Message{}
      |> Message.changeset(message_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"message" => message_params}, socket) do
    socket = assign(socket, :saving, true)

    changeset =
      %Message{}
      |> Message.changeset(message_params)
      |> Map.put(:action, :insert)

    if changeset.valid? do
      # Convert changeset to API payload
      message_data = Ecto.Changeset.apply_changes(changeset)

      result =
        if socket.assigns.message do
          MessagesClient.update_message(socket.assigns.message["id"] || socket.assigns.message[:id], message_data)
        else
          MessagesClient.create_message(message_data)
        end

      case result do
        {:ok, _message} ->
          if socket.assigns.on_save do
            send(socket.assigns.on_save, :saved)
          end
          {:noreply, assign(socket, :saving, false)}

        {:error, reason} ->
          error_msg = GatewayErrorHelper.format_gateway_error(reason)
          {:noreply, socket |> assign(:saving, false) |> assign(:error, error_msg)}
      end
    else
      {:noreply, socket |> assign(:saving, false) |> assign(:changeset, changeset)}
    end
  end

  def handle_event("cancel", _params, socket) do
    if socket.assigns.on_cancel do
      send(socket.assigns.on_cancel, :close)
    end
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-bold">
            <%= if @message, do: "Edit Message", else: "Create New Message" %>
          </h3>
          <button
            phx-click="cancel"
            phx-target={@myself}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <%= if @error do %>
          <div class="mb-4 rounded-md bg-red-50 border border-red-200 text-red-700 p-3 text-sm">
            <%= @error %>
          </div>
        <% end %>

        <%= if assigns[:changeset] do %>
          <.form
            for={@changeset}
            phx-submit="save"
            phx-change="validate"
            phx-target={@myself}
            class="space-y-4"
          >
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Tenant ID <span class="text-red-500">*</span>
              </label>
              <input
                type="text"
                name="message[tenant_id]"
                value={Ecto.Changeset.get_field(@changeset, :tenant_id)}
                class="w-full border rounded-md px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
                required
              />
              <%= if Ecto.Changeset.get_field(@changeset, :tenant_id) == nil && @changeset.action do %>
                <p class="mt-1 text-xs text-red-600">can't be blank</p>
              <% end %>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Model <span class="text-red-500">*</span>
              </label>
              <input
                type="text"
                name="message[model]"
                value={Ecto.Changeset.get_field(@changeset, :model)}
                placeholder="gpt-4, gpt-3.5-turbo, etc."
                class="w-full border rounded-md px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
                required
              />
              <%= if Ecto.Changeset.get_field(@changeset, :model) == nil && @changeset.action do %>
                <p class="mt-1 text-xs text-red-600">can't be blank</p>
              <% end %>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Content
              </label>
              <textarea
                name="message[content]"
                rows="6"
                placeholder="Enter message content..."
                class="w-full border rounded-md px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
              ><%= Ecto.Changeset.get_field(@changeset, :content) %></textarea>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Message Type
              </label>
              <select
                name="message[message_type]"
                class="w-full border rounded-md px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">Select type...</option>
                <option value="chat" selected={Ecto.Changeset.get_field(@changeset, :message_type) == "chat"}>Chat</option>
                <option value="completion" selected={Ecto.Changeset.get_field(@changeset, :message_type) == "completion"}>Completion</option>
                <option value="embedding" selected={Ecto.Changeset.get_field(@changeset, :message_type) == "embedding"}>Embedding</option>
                <option value="custom" selected={Ecto.Changeset.get_field(@changeset, :message_type) == "custom"}>Custom</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Status
              </label>
              <select
                name="message[status]"
                class="w-full border rounded-md px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">Select status...</option>
                <option value="pending" selected={Ecto.Changeset.get_field(@changeset, :status) == "pending"}>Pending</option>
                <option value="processing" selected={Ecto.Changeset.get_field(@changeset, :status) == "processing"}>Processing</option>
                <option value="success" selected={Ecto.Changeset.get_field(@changeset, :status) == "success"}>Success</option>
                <option value="error" selected={Ecto.Changeset.get_field(@changeset, :status) == "error"}>Error</option>
                <option value="cancelled" selected={Ecto.Changeset.get_field(@changeset, :status) == "cancelled"}>Cancelled</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Trace ID
              </label>
              <input
                type="text"
                name="message[trace_id]"
                value={Ecto.Changeset.get_field(@changeset, :trace_id)}
                placeholder="Optional trace ID"
                class="w-full border rounded-md px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Request ID
              </label>
              <input
                type="text"
                name="message[request_id]"
                value={Ecto.Changeset.get_field(@changeset, :request_id)}
                placeholder="Optional request ID"
                class="w-full border rounded-md px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            <div class="flex items-center justify-end space-x-3 pt-4 border-t">
              <button
                type="button"
                phx-click="cancel"
                phx-target={@myself}
                class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={@saving}
                class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
              >
                <%= if @saving, do: "Saving...", else: if(@message, do: "Update Message", else: "Create Message") %>
              </button>
            </div>
          </.form>
        <% else %>
          <p class="text-gray-500">Loading form...</p>
        <% end %>
      </div>
    </div>
    """
  end

end

