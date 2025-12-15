defmodule UiWebWeb.MessagesLive do
  use UiWebWeb, :live_view
  alias UiWeb.Services.GatewayClient
  alias UiWebWeb.Endpoint
  alias UiWebWeb.GatewayErrorHelper

  @poll_ms 10_000

  def mount(_params, _session, socket) do
    gw = Application.get_env(:ui_web, :gateway, []) |> Keyword.get(:url, "http://localhost:8081")
    tenant = "tenant_dev"
    sse = gw <> "/api/v1/messages/stream?tenant_id=" <> tenant

    socket =
      socket
      |> assign(page_title: "Messages")
      |> assign(messages: [])
      |> assign(selected: nil)
      |> assign(edit_payload: nil)
      |> assign(error: nil)
      |> assign(
        form: %{tenant_id: tenant, message_type: "chat", payload: "{}", trace_id: "trace_dev"}
      )
      |> assign(sse_url: sse)

    if connected?(socket) do
      # Subscribe to Phoenix Channels topic for this tenant to receive SSEBridge broadcasts
      Endpoint.subscribe("messages:" <> tenant)
      :timer.send_interval(@poll_ms, :poll)
      send(self(), :poll)
    end

    {:ok, socket}
  end

  # All handle_event/3 clauses grouped together
  def handle_event("update_msg", params, socket) do
    %{"payload" => payload} = params

    case socket.assigns.selected do
      %{} = sel ->
        id = sel["message_id"] || sel[:message_id]
        body = Map.merge(sel, %{"payload" => payload})

        case GatewayClient.put_json("/api/v1/messages/" <> to_string(id), body) do
          {:ok, updated} ->
            # optimistic refresh
            send(self(), :poll)
            {:noreply, assign(socket, selected: updated, edit_payload: payload, error: nil)}

          {:error, reason} ->
            msg = GatewayErrorHelper.format_gateway_error(reason)
            {:noreply, assign(socket, error: "Update failed. " <> msg)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("view", %{"id" => id}, socket) do
    case GatewayClient.get_json("/api/v1/messages/" <> id) do
      {:ok, msg} ->
        payload = msg["payload"] || msg[:payload] || "{}"
        {:noreply, assign(socket, selected: msg, edit_payload: payload, error: nil)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to load message. " <> msg)}
    end
  end

  def handle_event("delete_msg", %{"id" => id}, socket) do
    case GatewayClient.delete("/api/v1/messages/" <> id) do
      {:ok, _} ->
        send(self(), :poll)
        {:noreply, assign(socket, selected: nil, error: nil)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Delete failed. " <> msg)}
    end
  end

  def handle_event("submit", params, socket) do
    form = Map.get(params, "form", %{})

    body = %{
      "tenant_id" => form["tenant_id"],
      "message_type" => form["message_type"],
      "payload" => form["payload"],
      "trace_id" => form["trace_id"]
    }

    case GatewayClient.post_json("/api/v1/messages", body) do
      {:ok, _ack} ->
        send(self(), :poll)
        {:noreply, assign(socket, error: nil)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to create message. " <> msg)}
    end
  end

  def handle_event("sse_message", %{"event" => event, "data" => data}, socket) do
    msgs = socket.assigns.messages

    case event do
      "message_created" ->
        {:noreply, assign(socket, messages: [data | msgs])}

      "message_updated" ->
        id = data["message_id"] || data[:message_id]

        updated =
          Enum.map(msgs, fn m ->
            if (m["message_id"] || m[:message_id]) == id, do: data, else: m
          end)

        {:noreply, assign(socket, messages: updated)}

      "message_deleted" ->
        id = data["message_id"] || data[:message_id]
        filtered = Enum.reject(msgs, fn m -> (m["message_id"] || m[:message_id]) == id end)
        {:noreply, assign(socket, messages: filtered)}

      _ ->
        {:noreply, socket}
    end
  end

  # All handle_info/2 clauses grouped together
  def handle_info(:poll, socket) do
    case GatewayClient.get_json("/api/v1/messages") do
      {:ok, %{"items" => items}} -> {:noreply, assign(socket, messages: items, error: nil)}
      {:ok, items} when is_list(items) -> {:noreply, assign(socket, messages: items, error: nil)}
      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to load messages. " <> msg)}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "message_event",
          payload: %{"event" => event, "data" => data}
        },
        socket
      ) do
    handle_event("sse_message", %{"event" => event, "data" => data}, socket)
  end

  def render(assigns) do
    ~H"""
    <div class="py-8">
      <h2 class="text-2xl font-bold mb-4">Messages</h2>

      <div id="messages-sse" phx-hook="MessagesSSE" data-sse-url={@sse_url}></div>

      <%= if @error do %>
        <div class="mb-4 rounded bg-red-50 text-red-700 p-3 text-sm">
          <%= @error %>
        </div>
      <% end %>

      <div class="mb-6 bg-white p-4 shadow rounded">
        <h3 class="font-semibold mb-2">Create Message</h3>
        <form phx-submit="submit" class="space-y-2">
          <div>
            <label class="block text-sm text-gray-600 mb-1">Tenant ID</label>
            <input name="form[tenant_id]" value={@form.tenant_id} class="w-full border rounded px-2 py-1" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Message Type</label>
            <input name="form[message_type]" value={@form.message_type} class="w-full border rounded px-2 py-1" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Payload (JSON string)</label>
            <textarea name="form[payload]" class="w-full border rounded px-2 py-1 h-32 font-mono"><%= @form.payload %></textarea>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Trace ID</label>
            <input name="form[trace_id]" value={@form.trace_id} class="w-full border rounded px-2 py-1" />
          </div>
          <button type="submit" class="mt-2 bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700">Send</button>
        </form>
      </div>

      <div class="bg-white p-4 shadow rounded col-span-1">
        <h3 class="font-semibold mb-2">Latest</h3>
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead>
              <tr class="text-left text-gray-600 border-b">
                <th class="py-2 pr-4">message_id</th>
                <th class="py-2 pr-4">tenant_id</th>
                <th class="py-2 pr-4">type</th>
                <th class="py-2 pr-4">timestamp_ms</th>
                <th class="py-2 pr-4">actions</th>
              </tr>
            </thead>
            <tbody>
            <%= for m <- @messages do %>
              <tr class="border-b">
                <td class="py-2 pr-4"><%= m["message_id"] || m[:message_id] %></td>
                <td class="py-2 pr-4"><%= m["tenant_id"] || m[:tenant_id] %></td>
                <td class="py-2 pr-4"><%= m["message_type"] || m[:message_type] %></td>
                <td class="py-2 pr-4"><%= m["timestamp_ms"] || m[:timestamp_ms] %></td>
                <td class="py-2 pr-4">
                  <% id = m["message_id"] || m[:message_id] %>
                  <button phx-click="view" phx-value-id={id} class="text-blue-600 hover:underline mr-2">view</button>
                  <button phx-click="delete_msg" phx-value-id={id} class="text-red-600 hover:underline">delete</button>
                </td>
              </tr>
            <% end %>
            </tbody>
          </table>
        </div>
      </div>
      <div class="bg-white p-4 shadow rounded col-span-1">
        <h3 class="font-semibold mb-2">Selected</h3>
        <pre class="text-xs bg-gray-50 p-3 rounded overflow-auto max-h-96"><%= @selected && Jason.encode!(@selected, pretty: true) || "Select a message" %></pre>
        <%= if @selected do %>
          <div class="mt-3">
            <h4 class="font-semibold mb-1">Edit Payload</h4>
            <form phx-submit="update_msg" class="space-y-2">
              <textarea name="payload" class="w-full border rounded px-2 py-1 h-40 font-mono"><%= @edit_payload || "" %></textarea>
              <button type="submit" class="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700">Save</button>
            </form>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
