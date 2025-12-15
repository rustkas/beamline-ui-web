defmodule UiWebWeb.Components.URLPreview do
  use UiWebWeb, :live_component

  alias UiWeb.Services.URLPreviewService

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:preview_state, :empty)
     |> assign(:preview_data, nil)
     |> assign(:error_message, nil)
     |> assign(:show_preview, true)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:show_preview, fn -> true end)
      |> assign_new(:url, fn -> "" end)

    # Auto-fetch if URL changed and not empty
    current_url = assigns[:url] || ""
    previous_url = socket.assigns[:url] || ""

    socket =
      if current_url != "" && current_url != previous_url && socket.assigns.preview_state != :loading do
        # Trigger async fetch
        pid = self()
        component_id = socket.assigns.id

        Task.start(fn ->
          result = URLPreviewService.fetch_preview(current_url)
          send(pid, {:preview_result, component_id, result})
        end)

        socket
        |> assign(:preview_state, :loading)
        |> assign(:preview_data, nil)
        |> assign(:error_message, nil)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_info({:preview_result, component_id, result}, socket) do
    if component_id == socket.assigns.id do
      socket =
        case result do
          {:ok, data} ->
            socket
            |> assign(:preview_state, :success)
            |> assign(:preview_data, data)
            |> assign(:error_message, nil)

          {:error, :timeout} ->
            socket
            |> assign(:preview_state, :error)
            |> assign(:error_message, "Request timed out after 5 seconds")

          {:error, {:http_error, status}} ->
            socket
            |> assign(:preview_state, :error)
            |> assign(:error_message, "HTTP error: #{status}")

          {:error, :local_url_not_allowed} ->
            socket
            |> assign(:preview_state, :error)
            |> assign(:error_message, "Local URLs are not allowed for security reasons")

          {:error, :private_ip_not_allowed} ->
            socket
            |> assign(:preview_state, :error)
            |> assign(:error_message, "Private IP addresses are not allowed for security reasons")

          {:error, reason} ->
            socket
            |> assign(:preview_state, :error)
            |> assign(:error_message, "Failed to fetch preview: #{inspect(reason)}")
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("fetch_preview", %{"url" => url}, socket) do
    if url != "" do
      # Start async fetch
      socket =
        socket
        |> assign(:preview_state, :loading)
        |> assign(:preview_data, nil)
        |> assign(:error_message, nil)

      # Spawn async task
      pid = self()
      component_id = socket.assigns.id

      Task.start(fn ->
        result = URLPreviewService.fetch_preview(url)
        send(pid, {:preview_result, component_id, result})
      end)

      {:noreply, socket}
    else
      {:noreply, assign(socket, :preview_state, :empty)}
    end
  end

  @impl true
  def handle_event("refresh_preview", _params, socket) do
    url = socket.assigns.url || ""
    handle_event("fetch_preview", %{"url" => url}, socket)
  end

  @impl true
  def handle_event("clear_preview", _params, socket) do
    socket =
      socket
      |> assign(:preview_state, :empty)
      |> assign(:preview_data, nil)
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="url-preview-component mt-2" id={@id}>
      <%= if @show_preview do %>
        <%= case @preview_state do %>
          <% :empty -> %>
            <div class="text-sm text-gray-500 italic">
              Enter a URL to see preview
            </div>

          <% :loading -> %>
            <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
              <div class="flex items-center gap-2">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-indigo-600"></div>
                <span class="text-sm text-gray-600">Fetching preview...</span>
              </div>
            </div>

          <% :success -> %>
            <div class="border border-green-200 rounded-lg overflow-hidden bg-white shadow-sm">
              <!-- Header -->
              <div class="bg-green-50 px-4 py-2 border-b border-green-200 flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <svg class="h-4 w-4 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                  <span class="text-sm font-medium text-green-800">Preview</span>
                </div>

                <div class="flex items-center gap-2">
                  <button
                    type="button"
                    phx-click="refresh_preview"
                    phx-target={@myself}
                    class="text-sm text-green-700 hover:text-green-900"
                    title="Refresh preview"
                  >
                    ↻
                  </button>

                  <button
                    type="button"
                    phx-click="clear_preview"
                    phx-target={@myself}
                    class="text-sm text-green-700 hover:text-green-900"
                    title="Clear preview"
                  >
                    ×
                  </button>
                </div>
              </div>

              <!-- Preview Card -->
              <div class="p-4">
                <div class="flex gap-4">
                  <!-- Image (if available) -->
                  <%= if @preview_data.image do %>
                    <div class="flex-shrink-0">
                      <img
                        src={@preview_data.image}
                        alt="Preview"
                        class="w-24 h-24 object-cover rounded-lg border border-gray-200"
                        onerror="this.style.display='none'"
                      />
                    </div>
                  <% end %>

                  <!-- Text content -->
                  <div class="flex-1 min-w-0">
                    <h3 class="text-base font-semibold text-gray-900 truncate">
                      <%= @preview_data.title %>
                    </h3>

                    <%= if @preview_data.description && @preview_data.description != "" do %>
                      <p class="mt-1 text-sm text-gray-600 line-clamp-2">
                        <%= @preview_data.description %>
                      </p>
                    <% end %>

                    <div class="mt-2 flex items-center gap-2 text-xs text-gray-500">
                      <%= if @preview_data.favicon do %>
                        <img
                          src={@preview_data.favicon}
                          alt=""
                          class="w-4 h-4"
                          onerror="this.style.display='none'"
                        />
                      <% end %>
                      <span><%= @preview_data.domain %></span>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Footer with metrics -->
              <div class="bg-gray-50 px-4 py-2 text-xs text-gray-600 border-t border-gray-200">
                ✓ URL is accessible (<%= @preview_data[:status_code] || 200 %> OK, <%= @preview_data[:response_time_ms] || 0 %>ms)
              </div>
            </div>

          <% :error -> %>
            <div class="border border-red-200 rounded-lg p-4 bg-red-50">
              <div class="flex items-start gap-3">
                <svg class="h-5 w-5 text-red-600 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>

                <div class="flex-1">
                  <h4 class="text-sm font-medium text-red-800">Preview Failed</h4>
                  <p class="mt-1 text-sm text-red-700"><%= @error_message %></p>

                  <button
                    type="button"
                    phx-click="refresh_preview"
                    phx-target={@myself}
                    class="mt-2 text-sm text-red-700 hover:text-red-900 underline"
                  >
                    Try again
                  </button>
                </div>
              </div>
            </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end

