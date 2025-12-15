defmodule UiWebWeb.Components.URLPreviewComponent do
  @moduledoc """
  LiveComponent for URL preview using URLPreviewService.

  Displays a preview card with favicon, domain, title, description, and image
  for a given URL. Handles states: :idle, :ok, :error.

  This component is a pure UI layer over the already-safe `URLPreviewService`,
  which handles SSRF protection, URL validation, and metadata parsing.

  ## Usage

      <.live_component
        module={UiWebWeb.Components.URLPreviewComponent}
        id={"url-preview-#{@id}"}
        url={@form[:url].value}
        placeholder="Enter a URL to see preview"
      />

  ## Props

  - `id` (required) - Component ID
  - `url` (required) - URL to preview (String.t() | nil)
  - `placeholder` (optional) - Text for :idle state (default: nil)
  - `show_on_error?` (optional) - Show error UI (default: true)
  - `max_description_length` (optional) - Max description length (default: 200)

  ## Behavior

  - Empty/nil URL → `:idle` state (shows placeholder if provided)
  - Valid URL → synchronously calls `URLPreviewService.fetch_preview/1` and displays result
  - Error → displays user-friendly error message
  - URL changes → automatically refetches preview
  - Same URL → no refetch (optimization in real LiveView context)

  ## Configuration

  The service module can be configured via Application environment:

      config :ui_web, :url_preview_service_module, MyCustomService

  Defaults to `UiWeb.Services.URLPreviewService`.
  """
  use UiWebWeb, :live_component

  alias UiWeb.Services.URLPreviewService

  attr :id, :string, required: true
  attr :url, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :show_on_error?, :boolean, default: true
  attr :max_description_length, :integer, default: 200

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:url, nil)
     |> assign(:state, :idle)
     |> assign(:preview, nil)
     |> assign(:error, nil)
     |> assign_new(:placeholder, fn -> nil end)
     |> assign_new(:show_on_error?, fn -> true end)
     |> assign_new(:max_description_length, fn -> 200 end)}
  end

  @impl true
  def update(assigns, socket) do
    # 1. Берём старый URL ДО assign(assigns) (critical for detecting URL changes)
    previous_url = socket.assigns[:url]

    # 2. Нормализуем новый (из входящих assigns)
    new_url = normalize_url(assigns[:url])

    # 3. Обновляем assigns компонента
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:show_on_error?, fn -> true end)
      |> assign_new(:max_description_length, fn -> 200 end)

    cond do
      # Пустой URL → idle
      new_url in [nil, ""] ->
        {:ok,
         socket
         |> assign(:url, nil)
         |> assign(:state, :idle)
         |> assign(:preview, nil)
         |> assign(:error, nil)}

      # URL не изменился → ничего не делаем
      new_url == previous_url ->
        {:ok, socket}

      # Новый URL → делаем fetch прямо здесь (синхронно, с кэшированием)
      true ->
        case fetch_preview_cached(new_url) do
          {:ok, preview} ->
            {:ok,
             socket
             |> assign(:url, new_url)
             |> assign(:state, :ok)
             |> assign(:preview, preview)
             |> assign(:error, nil)}

          {:error, reason} ->
            {:ok,
             socket
             |> assign(:url, new_url)
             |> assign(:state, :error)
             |> assign(:preview, nil)
             |> assign(:error, reason)}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="url-preview-component" id={@id}>
      <%= case @state do %>
        <% :idle -> %>
          <%= if @placeholder do %>
            <div class="text-sm text-gray-500 italic">
              <%= @placeholder %>
            </div>
          <% end %>

        <% :loading -> %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50 animate-pulse">
            <div class="flex items-center gap-3">
              <div class="flex-shrink-0">
                <div class="w-4 h-4 bg-gray-300 rounded"></div>
              </div>
              <div class="flex-1 space-y-2">
                <div class="h-4 bg-gray-300 rounded w-3/4"></div>
                <div class="h-3 bg-gray-300 rounded w-1/2"></div>
              </div>
            </div>
          </div>

        <% :ok -> %>
          <article
            class="border border-gray-200 rounded-lg overflow-hidden bg-white shadow-sm hover:shadow-md transition-shadow duration-200"
            itemscope
            itemtype="https://schema.org/WebPage"
          >
            <a
              href={@preview.url}
              target="_blank"
              rel="noreferrer noopener"
              class="block focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 rounded-lg"
              itemprop="url"
            >
              <div class="p-4 sm:p-5">
                <div class="flex flex-col sm:flex-row gap-3 sm:gap-4">
                  <!-- Image (if available) -->
                  <%= if @preview.image do %>
                    <div class="flex-shrink-0 w-full sm:w-20 h-32 sm:h-20">
                      <img
                        src={@preview.image}
                        alt={@preview.title}
                        class="w-full h-full object-cover rounded-md"
                        loading="lazy"
                        itemprop="image"
                      />
                    </div>
                  <% end %>

                  <!-- Text content -->
                  <div class="flex-1 min-w-0">
                    <!-- Title -->
                    <h3
                      class="text-base sm:text-lg font-semibold text-gray-900 line-clamp-2 mb-1"
                      itemprop="name"
                    >
                      <%= @preview.title %>
                    </h3>

                    <!-- Description -->
                    <%= if @preview.description && @preview.description != "" do %>
                      <p
                        class="mt-1 text-sm text-gray-600 line-clamp-2 sm:line-clamp-3"
                        itemprop="description"
                      >
                        <%= truncate_description(@preview.description, @max_description_length) %>
                      </p>
                    <% end %>

                    <!-- Domain with favicon -->
                    <div class="mt-2 sm:mt-3 flex items-center gap-2 text-xs text-gray-500">
                      <%= if @preview.favicon do %>
                        <img
                          src={@preview.favicon}
                          alt=""
                          class="w-4 h-4 rounded flex-shrink-0"
                          onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
                          loading="lazy"
                        />
                        <div
                          class="w-4 h-4 rounded bg-gray-300 flex items-center justify-center text-[10px] font-semibold text-gray-600 hidden flex-shrink-0"
                        >
                          <%= String.first(@preview.domain) |> String.upcase() %>
                        </div>
                      <% else %>
                        <div
                          class="w-4 h-4 rounded bg-gray-300 flex items-center justify-center text-[10px] font-semibold text-gray-600 flex-shrink-0"
                        >
                          <%= String.first(@preview.domain) |> String.upcase() %>
                        </div>
                      <% end %>
                      <span class="truncate" itemprop="publisher" itemscope itemtype="https://schema.org/Organization">
                        <span itemprop="name"><%= @preview.domain %></span>
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </a>
          </article>

        <% :error -> %>
          <%= if @show_on_error? do %>
            <div class="border border-red-200 rounded-lg p-3 bg-red-50">
              <div class="flex items-start gap-2">
                <svg
                  class="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-red-800">
                    <%= format_error(@error) %>
                  </p>
                  <%= if extract_domain_from_error(@error) do %>
                    <p class="mt-1 text-xs text-red-600">
                      <%= extract_domain_from_error(@error) %>
                    </p>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
      <% end %>
    </div>
    """
  end

  # Fetch preview using the service with ETS cache
  # Cache TTL: 5 minutes (300 seconds)
  @cache_ttl_seconds 300
  @cache_table :url_preview_cache

  defp fetch_preview_cached(url) do
    # Initialize cache table if not exists (lazy initialization)
    ensure_cache_table()

    cache_key = url

    # Check cache
    try do
      case :ets.lookup(@cache_table, cache_key) do
        [{^cache_key, preview, timestamp}] ->
          # Check if cache entry is still valid
          if System.system_time(:second) - timestamp < @cache_ttl_seconds do
            {:ok, preview}
          else
            # Cache expired, fetch new and update cache
            fetch_and_cache(url)
          end

        [] ->
          # Cache miss, fetch and cache
          fetch_and_cache(url)
      end
    rescue
      ArgumentError ->
        # Table doesn't exist, fetch without cache
        fetch_preview(url)
    end
  end

  defp fetch_and_cache(url) do
    service_module = preview_service_module()

    case service_module.fetch_preview(url) do
      {:ok, preview} = result ->
        # Cache successful results only
        try do
          :ets.insert(@cache_table, {url, preview, System.system_time(:second)})
        rescue
          ArgumentError -> :ok
        end
        result

      {:error, _reason} = error ->
        # Don't cache errors
        error
    end
  end

  defp ensure_cache_table do
    try do
      case :ets.whereis(@cache_table) do
        :undefined ->
          :ets.new(@cache_table, [:set, :public, :named_table])

        _pid ->
          :ok
      end
    rescue
      ArgumentError ->
        # Table creation failed, continue without cache
        :ok
    end
  end

  # Fallback to direct fetch if cache is not available
  defp fetch_preview(url) do
    service_module = preview_service_module()
    service_module.fetch_preview(url)
  end

  defp preview_service_module do
    Application.get_env(:ui_web, :url_preview_service_module, URLPreviewService)
  end

  defp normalize_url(nil), do: nil

  defp normalize_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp normalize_url(_), do: nil

  defp truncate_description(description, max_length) do
    if String.length(description) > max_length do
      String.slice(description, 0, max_length) <> "…"
    else
      description
    end
  end

  defp format_error(:invalid_scheme), do: "Only http(s) links are supported"
  defp format_error(:local_url_not_allowed), do: "Private/internal links are not allowed"
  defp format_error(:private_ip_not_allowed), do: "Private/internal links are not allowed"
  defp format_error(:hostname_resolution_failed), do: "Cannot resolve hostname"
  defp format_error(:timeout), do: "Timed out while loading preview"
  defp format_error({:http_error, status}), do: "HTTP error (#{status})"
  defp format_error({:parse_error, _reason}), do: "Failed to parse page content"
  defp format_error(_reason), do: "Cannot load preview"

  defp extract_domain_from_error({:http_error, _status}), do: nil
  defp extract_domain_from_error(_error), do: nil

  # Function component wrapper for convenient usage in LiveView templates
  @doc """
  Function component wrapper for URLPreviewComponent.

  Provides a convenient way to use the URL preview component in LiveView templates
  without explicitly specifying `module={URLPreviewComponent}`.

  ## Examples

      <.url_preview id="preview-1" url={@form[:source_url].value} />

      <.url_preview
        id="preview-2"
        url={@form[:docs_url].value}
        placeholder="Enter documentation URL"
        max_description_length={150}
      />

  ## Props

  See `URLPreviewComponent` for available props.
  """
  attr :id, :string, required: true
  attr :url, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :show_on_error?, :boolean, default: true
  attr :max_description_length, :integer, default: 200

  def url_preview(assigns) do
    ~H"""
    <.live_component
      module={URLPreviewComponent}
      id={@id}
      url={@url}
      placeholder={@placeholder}
      show_on_error?={@show_on_error?}
      max_description_length={@max_description_length}
    />
    """
  end
end
