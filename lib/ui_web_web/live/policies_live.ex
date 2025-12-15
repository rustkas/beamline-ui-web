defmodule UiWebWeb.PoliciesLive do
  use UiWebWeb, :live_view
  alias UiWeb.Services.GatewayClient
  alias UiWebWeb.GatewayErrorHelper

  @poll_ms 15_000

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Policies")
      |> assign(tenant_id: "tenant_dev")
      |> assign(policy_id: "default")
      |> assign(policies: [])
      |> assign(editor: "{}")
      |> assign(original: "{}")
      |> assign(error: nil)

    if connected?(socket) do
      :timer.send_interval(@poll_ms, :poll)
      send(self(), :poll)
    end

    {:ok, socket}
  end

  def handle_info(:poll, socket) do
    t = socket.assigns.tenant_id

    case GatewayClient.get_json("/api/v1/policies/" <> t) do
      {:ok, %{"items" => items}} -> {:noreply, assign(socket, policies: items, error: nil)}
      {:ok, items} when is_list(items) -> {:noreply, assign(socket, policies: items, error: nil)}
      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to load policies. " <> msg)}
    end
  end

  def handle_event("load", _params, socket) do
    t = socket.assigns.tenant_id
    p = socket.assigns.policy_id

    case GatewayClient.get_json("/api/v1/policies/" <> t <> "/" <> p) do
      {:ok, policy} ->
        pretty = Jason.encode!(policy, pretty: true)
        {:noreply, assign(socket, editor: pretty, original: pretty, error: nil)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to load policy. " <> msg)}
    end
  end

  def handle_event("save", params, socket) do
    %{"editor" => editor} = params
    t = socket.assigns.tenant_id
    p = socket.assigns.policy_id

    with {:ok, json} <- Jason.decode(editor) do
      case GatewayClient.request(:put, "/api/v1/policies/" <> t <> "/" <> p, json) do
        {:ok, _} -> {:noreply, assign(socket, editor: editor, original: editor, error: nil)}
        {:error, reason} ->
          msg = GatewayErrorHelper.format_gateway_error(reason)
          {:noreply, assign(socket, error: "Failed to save policy. " <> msg)}
      end
    else
      _ -> {:noreply, assign(socket, error: "Invalid JSON")}
    end
  end

  def handle_event("delete", _params, socket) do
    t = socket.assigns.tenant_id
    p = socket.assigns.policy_id

    case GatewayClient.request(:delete, "/api/v1/policies/" <> t <> "/" <> p, nil) do
      {:ok, _} ->
        send(self(), :poll)
        {:noreply, assign(socket, error: nil)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to delete policy. " <> msg)}
    end
  end

  def handle_event("set", %{"tenant_id" => tenant_id, "policy_id" => policy_id}, socket) do
    {:noreply, assign(socket, tenant_id: tenant_id, policy_id: policy_id)}
  end

  def render(assigns) do
    ~H"""
    <div class="py-8">
      <h2 class="text-2xl font-bold mb-4">Policies</h2>

      <%= if @error do %>
        <div class="mb-4 rounded bg-red-50 text-red-700 p-3 text-sm"><%= @error %></div>
      <% end %>

      <div class="grid grid-cols-2 gap-4">
        <div class="bg-white p-4 shadow rounded">
          <h3 class="font-semibold mb-2">List</h3>
          <div class="mb-2 text-sm text-gray-600">Tenant: <%= @tenant_id %></div>
          <ul class="list-disc pl-6 text-sm">
            <%= for p <- @policies do %>
              <li><%= p["policy_id"] || p[:policy_id] || inspect(p) %></li>
            <% end %>
          </ul>
        </div>
        <div class="bg-white p-4 shadow rounded">
          <h3 class="font-semibold mb-2">Editor <span class={@editor != @original && "text-orange-600" || "text-gray-400"}>(<%= @editor != @original && "changed" || "saved" %>)</span></h3>
          <form phx-change="set" phx-submit="save" class="space-y-2">
            <div>
              <label class="block text-sm text-gray-600 mb-1">Tenant</label>
              <input name="tenant_id" value={@tenant_id} class="w-full border rounded px-2 py-1" />
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">Policy ID</label>
              <input name="policy_id" value={@policy_id} class="w-full border rounded px-2 py-1" />
            </div>
            <div class="flex gap-2 mb-2">
              <button type="button" phx-click="load" class="bg-gray-200 px-3 py-1 rounded hover:bg-gray-300">Load</button>
              <button type="button" phx-click="delete" class="bg-red-600 text-white px-3 py-1 rounded hover:bg-red-700">Delete</button>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="block text-sm text-gray-600 mb-1">Current</label>
                <textarea name="editor" class="w-full border rounded px-2 py-1 h-64 font-mono"><%= @editor %></textarea>
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">Original</label>
                <pre class="w-full border rounded px-2 py-1 h-64 font-mono overflow-auto bg-gray-50"><%= @original %></pre>
              </div>
            </div>
            <button class="mt-2 bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700">Save</button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
