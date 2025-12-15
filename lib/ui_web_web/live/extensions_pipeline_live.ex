defmodule UiWebWeb.ExtensionsPipelineLive do
  use UiWebWeb, :live_view
  alias UiWeb.Services.GatewayClient
  alias UiWebWeb.GatewayErrorHelper

  @poll_ms 10_000

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Extensions Pipeline Inspector")
      |> assign(tenant_id: "tenant_dev")
      |> assign(policy_id: "default")
      |> assign(policy: nil)
      |> assign(extensions: [])
      |> assign(extension_health: %{})
      |> assign(extension_circuit_states: %{})
      |> assign(pipeline_complexity: nil)
      |> assign(dry_run_result: nil)
      |> assign(dry_run_payload: "{\"message\": \"test\"}")
      |> assign(loading: false)
      |> assign(error: nil)

    if connected?(socket) do
      :timer.send_interval(@poll_ms, :poll)
      send(self(), :poll)
    end

    {:ok, socket}
  end

  def handle_info(:poll, socket) do
    socket =
      socket
      |> load_policy()
      |> load_extensions()
      |> load_extension_health()
      |> load_circuit_states()
      |> load_pipeline_complexity()

    {:noreply, socket}
  end

  def handle_event("set_tenant_policy", %{"tenant_id" => tenant_id, "policy_id" => policy_id}, socket) do
    socket =
      socket
      |> assign(tenant_id: tenant_id, policy_id: policy_id)
      |> load_policy()

    {:noreply, socket}
  end

  def handle_event("update_dry_run_payload", %{"value" => payload}, socket) do
    {:noreply, assign(socket, dry_run_payload: payload)}
  end

  def handle_event("update_dry_run_payload", %{"payload" => payload}, socket) do
    {:noreply, assign(socket, dry_run_payload: payload)}
  end

  def handle_event("run_dry_run", params, socket) do
    # Get payload from params or use current value
    payload = Map.get(params, "payload", socket.assigns.dry_run_payload)
    socket = assign(socket, loading: true, error: nil, dry_run_result: nil, dry_run_payload: payload)

    case run_dry_run(socket.assigns.tenant_id, socket.assigns.policy_id, payload) do
      {:ok, result} ->
        {:noreply, assign(socket, dry_run_result: result, loading: false)}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, assign(socket, error: "Dry-run failed: " <> msg, loading: false)}
    end
  end

  defp load_policy(socket) do
    tenant_id = socket.assigns.tenant_id
    policy_id = socket.assigns.policy_id

    case GatewayClient.get_json("/api/v1/policies/#{tenant_id}/#{policy_id}") do
      {:ok, policy} ->
        assign(socket, policy: policy, error: nil)

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        assign(socket, error: "Failed to load policy: " <> msg, policy: nil)
    end
  end

  defp load_extensions(socket) do
    case GatewayClient.get_json("/api/v1/extensions") do
      {:ok, %{"items" => items}} ->
        assign(socket, extensions: items, error: nil)

      {:ok, items} when is_list(items) ->
        assign(socket, extensions: items, error: nil)

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        assign(socket, error: "Failed to load extensions: " <> msg, extensions: [])
    end
  end

  defp load_extension_health(socket) do
    case GatewayClient.get_json("/api/v1/extensions/health") do
      {:ok, health_map} ->
        assign(socket, extension_health: health_map, error: nil)

      {:error, _reason} ->
        # Health endpoint might not be available, continue without it
        socket
    end
  end

  defp load_circuit_states(socket) do
    case GatewayClient.get_json("/api/v1/extensions/circuit-breakers") do
      {:ok, states_map} ->
        assign(socket, extension_circuit_states: states_map, error: nil)

      {:error, _reason} ->
        # Circuit breaker endpoint might not be available, continue without it
        socket
    end
  end

  defp load_pipeline_complexity(socket) do
    tenant_id = socket.assigns.tenant_id
    policy_id = socket.assigns.policy_id

    case GatewayClient.get_json("/api/v1/policies/#{tenant_id}/#{policy_id}/complexity") do
      {:ok, %{"complexity" => complexity}} ->
        # API returns {"complexity": {...}}
        assign(socket, pipeline_complexity: complexity, error: nil)

      {:ok, complexity_map} when is_map(complexity_map) ->
        # API returns complexity directly
        assign(socket, pipeline_complexity: complexity_map, error: nil)

      {:error, _reason} ->
        # Complexity endpoint might not be available, continue without it
        socket
    end
  end

  defp run_dry_run(tenant_id, policy_id, payload_json) do
    with {:ok, payload} <- Jason.decode(payload_json) do
      body = %{
        "tenant_id" => tenant_id,
        "policy_id" => policy_id,
        "payload" => payload,
        "dry_run" => true
      }

      GatewayClient.post_json("/api/v1/policies/dry-run", body)
    else
      {:error, _} = error ->
        error
    end
  end

  def render(assigns) do
    ~H"""
    <div class="py-8">
      <h2 class="text-2xl font-bold mb-4">Extensions Pipeline Inspector</h2>

      <%= if @error do %>
        <div class="mb-4 rounded bg-red-50 text-red-700 p-3 text-sm"><%= @error %></div>
      <% end %>

      <!-- Tenant/Policy Selector -->
      <div class="mb-6 bg-white p-4 shadow rounded">
        <h3 class="font-semibold mb-2">Policy Selection</h3>
        <form phx-submit="set_tenant_policy" class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">Tenant ID</label>
            <input
              name="tenant_id"
              value={@tenant_id}
              class="w-full border rounded px-2 py-1"
            />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">Policy ID</label>
            <input
              name="policy_id"
              value={@policy_id}
              class="w-full border rounded px-2 py-1"
            />
          </div>
          <div class="col-span-2">
            <button
              type="submit"
              class="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700"
            >
              Load Policy
            </button>
          </div>
        </form>
      </div>

      <!-- Policy Pipeline View -->
      <%= if @policy do %>
        <!-- Pipeline Complexity Assessment -->
        <%= if @pipeline_complexity do %>
          <div class="mb-6 bg-white p-4 shadow rounded">
            <h3 class="font-semibold mb-4">Pipeline Complexity Assessment</h3>
            <%= render_complexity_assessment(assigns) %>
          </div>
        <% end %>

        <div class="mb-6 bg-white p-4 shadow rounded">
          <h3 class="font-semibold mb-4">Pipeline Structure</h3>
          <div class="space-y-4">
            <!-- Pre-processors -->
            <%= if pre = Map.get(@policy, "pre") || Map.get(@policy, :pre) do %>
              <div>
                <h4 class="font-medium text-sm text-gray-700 mb-2">Pre-processors</h4>
                <div class="pl-4 space-y-2">
                  <%= for ext <- (if is_list(pre), do: pre, else: []) do %>
                    <%= render_extension_item(assigns, ext, "pre") %>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Validators -->
            <%= if validators = Map.get(@policy, "validators") || Map.get(@policy, :validators) do %>
              <div>
                <h4 class="font-medium text-sm text-gray-700 mb-2">Validators</h4>
                <div class="pl-4 space-y-2">
                  <%= for ext <- (if is_list(validators), do: validators, else: []) do %>
                    <%= render_extension_item(assigns, ext, "validator") %>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Post-processors -->
            <%= if post = Map.get(@policy, "post") || Map.get(@policy, :post) do %>
              <div>
                <h4 class="font-medium text-sm text-gray-700 mb-2">Post-processors</h4>
                <div class="pl-4 space-y-2">
                  <%= for ext <- (if is_list(post), do: post, else: []) do %>
                    <%= render_extension_item(assigns, ext, "post") %>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Extensions Registry -->
      <div class="mb-6 bg-white p-4 shadow rounded">
        <h3 class="font-semibold mb-4">Extensions Registry</h3>
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead>
              <tr class="border-b">
                <th class="text-left p-2">ID</th>
                <th class="text-left p-2">Type</th>
                <th class="text-left p-2">Subject</th>
                <th class="text-left p-2">Version</th>
                <th class="text-left p-2">Health</th>
                <th class="text-left p-2">Circuit State</th>
                <th class="text-left p-2">Instances</th>
              </tr>
            </thead>
            <tbody>
              <%= for ext <- @extensions do %>
                <tr class="border-b">
                  <td class="p-2 font-mono text-xs"><%= ext["id"] || ext[:id] %></td>
                  <td class="p-2"><%= ext["type"] || ext[:type] %></td>
                  <td class="p-2 font-mono text-xs"><%= ext["subject"] || ext[:subject] %></td>
                  <td class="p-2"><%= ext["version"] || ext[:version] || "N/A" %></td>
                  <td class="p-2">
                    <%= render_health_status(assigns, ext["id"] || ext[:id]) %>
                  </td>
                  <td class="p-2">
                    <%= render_circuit_state(assigns, ext["id"] || ext[:id]) %>
                  </td>
                  <td class="p-2">
                    <%= ext["instances"] || ext[:instances] || "N/A" %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Dry Run -->
      <div class="mb-6 bg-white p-4 shadow rounded">
        <h3 class="font-semibold mb-4">Dry Run Pipeline</h3>
        <form phx-submit="run_dry_run" class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">Test Payload (JSON)</label>
            <textarea
              name="payload"
              phx-blur="update_dry_run_payload"
              phx-debounce="300"
              class="w-full border rounded px-2 py-1 h-32 font-mono text-xs"
              placeholder='{"message": "test"}'
            ><%= @dry_run_payload %></textarea>
          </div>
          <div>
            <button
              type="submit"
              disabled={@loading}
              class="bg-green-600 text-white px-3 py-1 rounded hover:bg-green-700 disabled:opacity-50"
            >
              <%= if @loading, do: "Running...", else: "Run Dry Run" %>
            </button>
          </div>
        </form>

        <%= if @dry_run_result do %>
          <div class="mt-4 p-4 bg-gray-50 rounded">
            <h4 class="font-medium mb-2">Dry Run Result</h4>
            <pre class="text-xs overflow-auto max-h-96"><%= Jason.encode!(@dry_run_result, pretty: true) %></pre>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_extension_item(assigns, ext, type) do
    ext_id = ext["id"] || ext[:id] || "unknown"
    mode = ext["mode"] || ext[:mode] || "optional"
    on_fail = ext["on_fail"] || ext[:on_fail]

    health = Map.get(assigns.extension_health, ext_id, %{})
    circuit_state = Map.get(assigns.extension_circuit_states, ext_id, "unknown")

    ~H"""
    <div class="flex items-center gap-2 p-2 bg-gray-50 rounded">
      <span class="font-mono text-xs"><%= ext_id %></span>
      <span class="text-xs text-gray-500">(<%= type %>)</span>
      <%= if mode do %>
        <span class="text-xs px-1 py-0.5 bg-blue-100 rounded">mode: <%= mode %></span>
      <% end %>
      <%= if on_fail do %>
        <span class="text-xs px-1 py-0.5 bg-yellow-100 rounded">on_fail: <%= on_fail %></span>
      <% end %>
      <%= render_health_badge(health) %>
      <%= render_circuit_badge(circuit_state) %>
    </div>
    """
  end

  defp render_health_status(assigns, ext_id) do
    health = Map.get(assigns.extension_health, ext_id, %{})
    render_health_badge(health)
  end

  defp render_health_badge(health) when is_map(health) do
    status = health["status"] || health[:status] || "unknown"
    success_rate = health["success_rate"] || health[:success_rate]

    status_class =
      case status do
        "healthy" -> "bg-green-100 text-green-800"
        "degraded" -> "bg-yellow-100 text-yellow-800"
        "unhealthy" -> "bg-red-100 text-red-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    ~H"""
    <span class={"text-xs px-1 py-0.5 rounded #{status_class}"}>
      <%= status %>
      <%= if success_rate do %>
        (<%= :erlang.float_to_binary(success_rate * 100, decimals: 1) %>%)
      <% end %>
    </span>
    """
  end

  defp render_health_badge(_), do: ~H"<span class="text-xs text-gray-500">N/A</span>"

  defp render_circuit_state(assigns, ext_id) do
    circuit_state = Map.get(assigns.extension_circuit_states, ext_id, "unknown")
    render_circuit_badge(circuit_state)
  end

  defp render_circuit_badge(state) when is_binary(state) do
    state_class =
      case state do
        "closed" -> "bg-green-100 text-green-800"
        "open" -> "bg-red-100 text-red-800"
        "half_open" -> "bg-yellow-100 text-yellow-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    ~H"""
    <span class={"text-xs px-1 py-0.5 rounded #{state_class}"}><%= state %></span>
    """
  end

  defp render_circuit_badge(_), do: ~H"<span class="text-xs text-gray-500">N/A</span>"

  defp render_complexity_assessment(assigns) do
    complexity = assigns.pipeline_complexity
    complexity_level = complexity["complexity_level"] || complexity[:complexity_level] || "unknown"
    complexity_score = complexity["complexity_score"] || complexity[:complexity_score] || 0
    total_extensions = complexity["total_extensions"] || complexity[:total_extensions] || 0
    estimated_latency = complexity["estimated_latency_ms"] || complexity[:estimated_latency_ms] || 0
    warnings = complexity["warnings"] || complexity[:warnings] || []
    recommendations = complexity["recommendations"] || complexity[:recommendations] || []
    recommended_limits = complexity["recommended_limits"] || complexity[:recommended_limits] || %{}

    level_class =
      case complexity_level do
        "low" -> "bg-green-100 text-green-800"
        "medium" -> "bg-yellow-100 text-yellow-800"
        "high" -> "bg-orange-100 text-orange-800"
        "very_high" -> "bg-red-100 text-red-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    ~H"""
    <div class="space-y-4">
      <!-- Complexity Score -->
      <div class="flex items-center gap-4">
        <div>
          <span class="text-sm text-gray-600">Complexity Score:</span>
          <span class={"ml-2 px-2 py-1 rounded text-sm font-medium #{level_class}"}>
            <%= complexity_score %> (<%= complexity_level %>)
          </span>
        </div>
        <div>
          <span class="text-sm text-gray-600">Total Extensions:</span>
          <span class="ml-2 font-mono text-sm"><%= total_extensions %></span>
        </div>
        <div>
          <span class="text-sm text-gray-600">Estimated Latency:</span>
          <span class="ml-2 font-mono text-sm"><%= estimated_latency %>ms</span>
        </div>
      </div>

      <!-- Recommended Limits -->
      <div class="text-sm text-gray-600">
        <span class="font-medium">Recommended Limits:</span>
        <span class="ml-2">
          Total: <%= recommended_limits["max_total"] || recommended_limits[:max_total] || 4 %>,
          Pre: <%= recommended_limits["max_pre"] || recommended_limits[:max_pre] || 2 %>,
          Validators: <%= recommended_limits["max_validators"] || recommended_limits[:max_validators] || 2 %>,
          Post: <%= recommended_limits["max_post"] || recommended_limits[:max_post] || 2 %>
        </span>
      </div>

      <!-- Warnings -->
      <%= if length(warnings) > 0 do %>
        <div class="bg-yellow-50 border border-yellow-200 rounded p-3">
          <h4 class="font-medium text-yellow-800 mb-2">⚠️ Warnings</h4>
          <ul class="list-disc list-inside text-sm text-yellow-700 space-y-1">
            <%= for warning <- warnings do %>
              <li><%= warning %></li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <!-- Recommendations -->
      <%= if length(recommendations) > 0 do %>
        <div class="bg-blue-50 border border-blue-200 rounded p-3">
          <h4 class="font-medium text-blue-800 mb-2">💡 Recommendations</h4>
          <ul class="list-disc list-inside text-sm text-blue-700 space-y-1">
            <%= for rec <- recommendations do %>
              <li><%= rec %></li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end
end

