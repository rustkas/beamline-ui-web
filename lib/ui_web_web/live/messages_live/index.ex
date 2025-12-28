defmodule UiWebWeb.MessagesLive.Index do
  use UiWebWeb, :live_view

  alias UiWeb.Services.MessagesClient
  alias UiWebWeb.GatewayErrorHelper
  alias UiWeb.Messages.PaginationLogic
  alias UiWeb.Telemetry.LiveViewHelpers

  require Calendar

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(UiWeb.PubSub, "messages:updates")
      context = LiveViewHelpers.get_context(socket)
      tenant_id = Map.get(context, :tenant_id) || Application.get_env(:ui_web, :tenant_id, "tenant_dev")
      UiWebWeb.Endpoint.subscribe("messages:" <> tenant_id)
    end

    socket =
      socket
      |> assign(:page_title, "Messages")
      |> assign(:loading, true)
      |> assign(:messages, [])
      |> assign(:selected_ids, MapSet.new())
      |> assign(:filter_status, "all")
      |> assign(:filter_type, "all")
      |> assign(:search_query, "")
      |> assign(:sort_by, "created_at")
      |> assign(:sort_order, "desc")
      |> assign(:pagination, %{"total" => 0, "limit" => 50, "offset" => 0, "has_more" => false})
      |> load_messages()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:filter_status, Map.get(params, "status", "all"))
      |> assign(:filter_type, Map.get(params, "type", "all"))
      |> assign(:search_query, Map.get(params, "search", ""))
      |> load_messages()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, status: status))}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, type: type))}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    # Debounce search (use phx-debounce="300" in template)
    {:noreply, push_patch(socket, to: build_path(socket, search: query))}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    current_field = socket.assigns.sort_by

    # Toggle order if same field
    order =
      if current_field == field do
        if socket.assigns.sort_order == "asc", do: "desc", else: "asc"
      else
        "desc"
      end

    socket =
      socket
      |> assign(:sort_by, field)
      |> assign(:sort_order, order)
      |> load_messages()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected_ids =
      if MapSet.member?(socket.assigns.selected_ids, id) do
        MapSet.delete(socket.assigns.selected_ids, id)
      else
        MapSet.put(socket.assigns.selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, selected_ids)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    selected_ids =
      socket.assigns.messages
      |> Enum.map(& &1["id"])
      |> MapSet.new()

    {:noreply, assign(socket, :selected_ids, selected_ids)}
  end

  @impl true
  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  @impl true
  def handle_event("bulk_delete", _params, socket) do
    ids = MapSet.to_list(socket.assigns.selected_ids)

    # Emit LiveView action event
    LiveViewHelpers.emit_action(socket, "bulk_delete", %{
      selection_count: length(ids)
    })

    if length(ids) > 0 do
      context = LiveViewHelpers.get_context(socket)
      case MessagesClient.bulk_delete_messages(ids, context) do
        {:ok, %{"deleted_count" => count}} ->
          socket =
            socket
            |> put_flash(:info, "Deleted #{count} messages")
            |> assign(:selected_ids, MapSet.new())
            |> load_messages()

          {:noreply, socket}

        {:error, reason} ->
          msg = GatewayErrorHelper.format_gateway_error(reason)
          {:noreply, put_flash(socket, :error, "Bulk delete failed. " <> msg)}
      end
    else
      {:noreply, put_flash(socket, :warning, "No messages selected")}
    end
  end

  @impl true
  def handle_event("export", %{"format" => format}, socket) do
    ids = MapSet.to_list(socket.assigns.selected_ids)

    # Emit LiveView action event
    LiveViewHelpers.emit_action(socket, "export", %{
      format: format,
      selection_count: length(ids)
    })

    context = LiveViewHelpers.get_context(socket)
    with true <- length(ids) > 0,
         {:ok, content} <- MessagesClient.export_messages(ids, format, context) do
      # Trigger browser download
      filename = "messages_export_#{DateTime.utc_now() |> DateTime.to_unix()}.#{format}"

      {:noreply,
       socket
       |> push_event("download", %{
         content: Base.encode64(content),
         filename: filename,
         mime_type: mime_type(format)
       })}
    else
      false ->
        {:noreply, put_flash(socket, :warning, "No messages selected")}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, put_flash(socket, :error, "Export failed. " <> msg)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Emit LiveView action event
    LiveViewHelpers.emit_action(socket, "delete", %{
      message_id: id
    })

    context = LiveViewHelpers.get_context(socket)
    case MessagesClient.delete_message(id, context) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Message deleted")
          |> load_messages()

        {:noreply, socket}

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        {:noreply, put_flash(socket, :error, "Delete failed. " <> msg)}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    %{
      "offset" => offset,
      "limit" => limit
    } = socket.assigns.pagination

    new_offset = PaginationLogic.prev_offset(offset, limit)

    socket =
      socket
      |> update(:pagination, fn pag ->
        Map.put(pag, "offset", new_offset)
      end)
      |> load_messages()

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    %{
      "offset" => offset,
      "limit" => limit,
      "has_more" => has_more
    } = socket.assigns.pagination

    new_offset = PaginationLogic.next_offset(offset, limit, has_more)

    socket =
      socket
      |> update(:pagination, fn pag ->
        Map.put(pag, "offset", new_offset)
      end)
      |> load_messages()

    {:noreply, socket}
  end

  # Real-time updates

  @impl true
  def handle_info({:event, %{"type" => "message_created", "data" => message}}, socket) do
    # Only prepend if on first page
    if socket.assigns.pagination["offset"] == 0 do
      messages = [message | socket.assigns.messages] |> Enum.take(socket.assigns.pagination["limit"])
      {:noreply, assign(socket, :messages, messages)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:event, %{"type" => "message_updated", "data" => message}}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn msg ->
        if (msg["id"] || msg[:id]) == (message["id"] || message[:id]), do: message, else: msg
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info({:event, %{"type" => "message_deleted", "data" => %{"id" => id}}}, socket) do
    messages = Enum.reject(socket.assigns.messages, fn msg -> (msg["id"] || msg[:id]) == id end)
    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: _t, event: "message_event", payload: %{"event" => type, "data" => data}}, socket) do
    case type do
      "message_created" ->
        handle_info({:event, %{"type" => "message_created", "data" => data}}, socket)

      "message_updated" ->
        handle_info({:event, %{"type" => "message_updated", "data" => data}}, socket)

      "message_deleted" ->
        handle_info({:event, %{"type" => "message_deleted", "data" => %{"id" => (data["id"] || data[:id])}}}, socket)

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:event, _event}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({UiWebWeb.MessagesLive.FormComponent, {:saved, _message}}, socket) do
    {:noreply, load_messages(socket)}
  end

  # Private helpers

  defp load_messages(socket) do
    context = LiveViewHelpers.get_context(socket)
    opts = [
      status: (if socket.assigns.filter_status != "all", do: socket.assigns.filter_status),
      type: (if socket.assigns.filter_type != "all", do: socket.assigns.filter_type),
      search: socket.assigns.search_query,
      sort: socket.assigns.sort_by,
      order: socket.assigns.sort_order,
      limit: socket.assigns.pagination["limit"],
      offset: socket.assigns.pagination["offset"]
    ]
    |> Keyword.merge(context)

    case MessagesClient.list_messages(opts) do
      {:ok, %{"data" => messages, "pagination" => pagination}} ->
        assign(socket, loading: false, messages: messages, pagination: pagination)

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        socket
        |> assign(:loading, false)
        |> assign(:messages, [])  # Clear messages on error
        |> put_flash(:error, "Failed to load messages. " <> msg)
    end
  end

  defp build_path(socket, updates) do
    params =
      %{
        "status" => socket.assigns.filter_status,
        "type" => socket.assigns.filter_type,
        "search" => socket.assigns.search_query
      }
      |> Map.merge(Map.new(updates, fn {k, v} -> {to_string(k), v} end))
      |> Enum.reject(fn {_k, v} -> v == "" or v == "all" end)
      |> Map.new()

    query_string = URI.encode_query(params)
    ~p"/app/#{socket.assigns.tenant_id}/messages?#{query_string}"
  end

  defp mime_type("json"), do: "application/json"
  defp mime_type("csv"), do: "text/csv"

  def status_badge_class("pending"), do: "bg-yellow-100 text-yellow-800"
  def status_badge_class("processing"), do: "bg-blue-100 text-blue-800"
  def status_badge_class("completed"), do: "bg-green-100 text-green-800"
  def status_badge_class("failed"), do: "bg-red-100 text-red-800"
  def status_badge_class(_), do: "bg-gray-100 text-gray-800"

  def sort_indicator(current_field, field, order) when current_field == field do
    if order == "asc" do
      "↑"
    else
      "↓"
    end
  end

  def sort_indicator(_, _, _), do: ""

  def format_datetime(nil), do: "—"
  def format_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, dt, _} ->
        # Format: YYYY-MM-DD HH:MM:SS
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
end
