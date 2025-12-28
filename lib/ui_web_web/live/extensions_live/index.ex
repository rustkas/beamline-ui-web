defmodule UiWebWeb.ExtensionsLive.Index do
  @moduledoc """
  Extensions Registry LiveView - List page for managing NATS-based extensions.
  """
  use UiWebWeb, :live_view

  alias UiWeb.Services.ExtensionsClient
  alias UiWeb.Services.GatewayClient
  alias UiWebWeb.GatewayErrorHelper
  alias UiWeb.Telemetry.LiveViewHelpers
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      PubSub.subscribe(UiWeb.PubSub, "extensions:updates")

      # Initial health check (will use cache if available)
      GatewayClient.check_health()
    end

    socket =
      socket
      |> assign(:page_title, "Extensions Registry")
      |> assign(:loading, true)
      |> assign(:extensions, [])
      |> assign(:filter_type, "all")
      |> assign(:filter_status, "all")
      |> assign(:pagination, %{"total" => 0, "limit" => 20, "offset" => 0, "has_more" => false})
      |> load_extensions()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_type = Map.get(params, "type", "all")
    filter_status = Map.get(params, "status", "all")

    socket =
      socket
      |> assign(:filter_type, filter_type)
      |> assign(:filter_status, filter_status)
      |> load_extensions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/#{socket.assigns.tenant_id}/extensions?type=#{type}&status=#{socket.assigns.filter_status}")}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/#{socket.assigns.tenant_id}/extensions?type=#{socket.assigns.filter_type}&status=#{status}")}
  end

  @impl true
  def handle_event("toggle_extension", %{"id" => id} = params, socket) do
    # Handle both string and boolean enabled values
    enabled_str = Map.get(params, "enabled", "false")
    enabled = enabled_str == "true" || enabled_str == true

    # Emit LiveView action event
    LiveViewHelpers.emit_action(socket, "toggle_extension", %{
      extension_id: id,
      enabled: !enabled
    })

    context = LiveViewHelpers.get_context(socket)
    case ExtensionsClient.toggle_extension(id, !enabled, context) do
      {:ok, _updated} ->
        socket =
          socket
          |> put_flash(:info, "Extension #{if enabled, do: "disabled", else: "enabled"} successfully")
          |> load_extensions()

        {:noreply, socket}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, put_flash(socket, :error, "Failed to toggle extension. " <> msg)}
    end
  end

  @impl true
  def handle_event("delete_extension", %{"id" => id}, socket) do
    # Emit LiveView action event
    LiveViewHelpers.emit_action(socket, "delete_extension", %{
      extension_id: id
    })

    context = LiveViewHelpers.get_context(socket)
    case ExtensionsClient.delete_extension(id, context) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Extension deleted successfully")
          |> load_extensions()

        {:noreply, socket}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, put_flash(socket, :error, "Failed to delete extension. " <> msg)}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    pagination = socket.assigns.pagination
    new_offset = max(0, pagination["offset"] - pagination["limit"])

    socket =
      socket
      |> assign(:pagination, %{pagination | "offset" => new_offset})
      |> load_extensions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    pagination = socket.assigns.pagination
    new_offset = pagination["offset"] + pagination["limit"]

    socket =
      socket
      |> assign(:pagination, %{pagination | "offset" => new_offset})
      |> load_extensions()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:extension_updated, extension}, socket) do
    # Real-time update from PubSub
    extensions =
      Enum.map(socket.assigns.extensions, fn ext ->
        if ext["id"] == extension["id"], do: extension, else: ext
      end)

    {:noreply, assign(socket, :extensions, extensions)}
  end

  # Private helpers

  defp load_extensions(socket) do
    context = LiveViewHelpers.get_context(socket)
    opts = build_filter_opts(socket.assigns)
    |> Keyword.merge(context)

    case ExtensionsClient.list_extensions(opts) do
      {:ok, %{"data" => extensions, "pagination" => pagination}} ->
        socket
        |> assign(:loading, false)
        |> assign(:extensions, extensions)
        |> assign(:pagination, pagination)
        |> assign(:gateway_error, nil)

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        message = "Failed to load extensions. " <> msg

        socket
        |> assign(:loading, false)
        |> assign(:extensions, [])
        |> assign(:gateway_error, message)
        |> put_flash(:error, message)
    end
  end

  defp build_filter_opts(assigns) do
    pagination = assigns.pagination
    opts = [limit: pagination["limit"], offset: pagination["offset"]]

    opts =
      if assigns.filter_type != "all",
        do: Keyword.put(opts, :type, assigns.filter_type),
        else: opts

    if assigns.filter_status != "all",
      do: Keyword.put(opts, :status, assigns.filter_status),
      else: opts
  end

  def health_badge_class("healthy"), do: "bg-green-100 text-green-800"
  def health_badge_class("degraded"), do: "bg-yellow-100 text-yellow-800"
  def health_badge_class("down"), do: "bg-red-100 text-red-800"
  def health_badge_class(_), do: "bg-gray-100 text-gray-800"

  def type_badge_class("provider"), do: "bg-purple-100 text-purple-800"
  def type_badge_class("validator"), do: "bg-blue-100 text-blue-800"
  def type_badge_class("pre"), do: "bg-indigo-100 text-indigo-800"
  def type_badge_class("post"), do: "bg-pink-100 text-pink-800"
  def type_badge_class(_), do: "bg-gray-100 text-gray-800"
end
