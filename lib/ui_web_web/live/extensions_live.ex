defmodule UiWebWeb.ExtensionsLive do
  use UiWebWeb, :live_view
  alias UiWeb.Services.GatewayClient
  alias UiWebWeb.GatewayErrorHelper

  @poll_ms 20_000

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Extensions")
      |> assign(blocks: [])
      |> assign(selected: nil)
      |> assign(
        form: %{
          type: "demo.block",
          version: "1.0.0",
          input_schema: "{}",
          output_schema: "{}",
          capabilities: "sync,stream",
          metadata: "{}"
        }
      )
      |> assign(error: nil)

    if connected?(socket) do
      :timer.send_interval(@poll_ms, :poll)
      send(self(), :poll)
    end

    {:ok, socket}
  end

  def handle_info(:poll, socket) do
    case GatewayClient.get_json("/api/v1/registry/blocks") do
      {:ok, %{"items" => items}} -> {:noreply, assign(socket, blocks: items, error: nil)}
      {:ok, items} when is_list(items) -> {:noreply, assign(socket, blocks: items, error: nil)}
      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to load blocks. " <> msg)}
    end
  end

  def handle_event("select", %{"type" => type}, socket) do
    case GatewayClient.get_json("/api/v1/registry/blocks/" <> type) do
      {:ok, manifest} -> {:noreply, assign(socket, selected: manifest, error: nil)}
      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to load block. " <> msg)}
    end
  end

  def handle_event("register", params, socket) do
    form = Map.get(params, "form", %{})
    type = form["type"] || socket.assigns.form.type
    version = form["version"] || socket.assigns.form.version

    with {:ok, input_schema} <- Jason.decode(form["input_schema"] || "{}"),
         {:ok, output_schema} <- Jason.decode(form["output_schema"] || "{}"),
         {:ok, metadata} <- Jason.decode(form["metadata"] || "{}") do
      caps =
        (form["capabilities"] || "")
        |> String.split([",", " "], trim: true)
        |> Enum.reject(&(&1 == ""))

      body = %{
        "type" => type,
        "version" => version,
        "schema" => %{"input" => input_schema, "output" => output_schema},
        "capabilities" => caps,
        "metadata" => metadata
      }

      case GatewayClient.post_json("/api/v1/registry/blocks/" <> type <> "/" <> version, body) do
        {:ok, _} ->
          send(self(), :poll)
          {:noreply, assign(socket, error: nil)}

        {:error, reason} ->
          msg = GatewayErrorHelper.format_gateway_error(reason)
          {:noreply, assign(socket, error: "Failed to register block. " <> msg)}
      end
    else
      _ -> {:noreply, assign(socket, error: "Invalid JSON in input/output schema or metadata")}
    end
  end

  def handle_event("unregister", params, socket) do
    type = params["type"] || socket.assigns.form.type
    version = params["version"] || socket.assigns.form.version

    case GatewayClient.delete("/api/v1/registry/blocks/" <> type <> "/" <> version) do
      {:ok, _} ->
        send(self(), :poll)
        {:noreply, assign(socket, error: nil)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Failed to unregister block. " <> msg)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="py-8">
      <h2 class="text-2xl font-bold mb-4">Extensions Registry</h2>

      <%= if @error do %>
        <div class="mb-4 rounded bg-red-50 text-red-700 p-3 text-sm"><%= @error %></div>
      <% end %>

      <div class="grid grid-cols-2 gap-4">
        <div class="bg-white p-4 shadow rounded">
          <h3 class="font-semibold mb-2">Available Blocks</h3>
          <ul class="list-disc pl-6 text-sm">
            <%= for b <- @blocks do %>
              <li>
                <button phx-click="select" phx-value-type={b["type"] || b[:type]}
                        class="text-blue-600 hover:underline">
                  <%= b["type"] || b[:type] || inspect(b) %>
                </button>
              </li>
            <% end %>
          </ul>
        </div>
        <div class="bg-white p-4 shadow rounded">
          <h3 class="font-semibold mb-2">Manifest</h3>
          <pre class="text-xs bg-gray-50 p-3 rounded overflow-auto max-h-96"><%= @selected && Jason.encode!(@selected, pretty: true) || "Select a block" %></pre>
        </div>
      </div>

      <div class="mt-6 bg-white p-4 shadow rounded">
        <h3 class="font-semibold mb-2">Register / Unregister Block</h3>
        <form phx-submit="register" class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">Type</label>
            <input name="form[type]" value={@form.type} class="w-full border rounded px-2 py-1" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Version</label>
            <input name="form[version]" value={@form.version} class="w-full border rounded px-2 py-1" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Capabilities (comma separated)</label>
            <input name="form[capabilities]" value={@form.capabilities} class="w-full border rounded px-2 py-1" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Metadata (JSON)</label>
            <textarea name="form[metadata]" class="w-full border rounded px-2 py-1 h-24 font-mono"><%= @form.metadata %></textarea>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Input Schema (JSON)</label>
            <textarea name="form[input_schema]" class="w-full border rounded px-2 py-1 h-32 font-mono"><%= @form.input_schema %></textarea>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Output Schema (JSON)</label>
            <textarea name="form[output_schema]" class="w-full border rounded px-2 py-1 h-32 font-mono"><%= @form.output_schema %></textarea>
          </div>
          <div class="col-span-2 flex gap-2">
            <button type="submit" class="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700">Register / Update</button>
            <button type="button" phx-click="unregister" phx-value-type={@form.type} phx-value-version={@form.version} class="bg-red-600 text-white px-3 py-1 rounded hover:bg-red-700">Unregister</button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
