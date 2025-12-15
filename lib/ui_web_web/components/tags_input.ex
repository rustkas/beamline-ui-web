defmodule UiWebWeb.Components.TagsInput do
  @moduledoc """
  Tags input component for LiveView forms.

  The component renders a list of tags with an input field, supports autocomplete,
  enforces validation rules, and notifies the parent LiveView about changes.

  ## Usage

  In the parent LiveView:

      defmodule UiWebWeb.ExtensionsLive.Form do
        use UiWebWeb, :live_view
        alias UiWebWeb.Components.TagsInput

        @impl true
        def mount(_params, _session, socket) do
          changeset = Extensions.change_extension(%Extension{})
          form = to_form(changeset)
          {:ok, socket |> assign(:form, form) |> assign(:suggestions, ~w(ai ml nlp llm streaming))}
        end

        @impl true
        def handle_info({TagsInput, {:tags_updated, _id, tags}}, socket) do
          form = socket.assigns.form
          {:noreply, assign(socket, :form, %{form | source: %{form.source | changes: %{tags: tags}}})}
        end

        @impl true
        def render(assigns) do
          ~H\"\"\"
          <.form for={@form}>
            <.live_component module={TagsInput} id="extension-tags" field={@form[:tags]} suggestions={@suggestions} max_tags={10} />
          </.form>
          \"\"\"
        end
      end

  ## Attributes

    * `:id` – unique component ID. Required.

    * `:field` – form field map with at least:

        * `:name` – the input name (string)

        * `:value` – list of tags (`[String.t()]`) or `nil`

      Required.

    * `:suggestions` – list of suggested tags (autocomplete source). Optional, defaults to `[]`.

    * `:max_tags` – maximum number of tags allowed. Optional, defaults to `20`.

  ## Validation rules

    * Tag format: `/^[a-z0-9-]+$/i`

    * Maximum length: 30 characters

    * Duplicates are not allowed

    * Input is trimmed (`String.trim/1`)

    * Case-sensitive comparison (tags `"OpenAI"` and `"openai"` are considered different)

  All validation happens on `"add_tag"`; invalid tags do not get added and an error
  message is shown in the component.

  ## Behavior

    * **Single source of truth** – the current list of tags is always taken from
      `field.value` in `update/2` and mirrored into `@tags` assign.

    * **Atomic sync** – every change (add/remove/backspace) updates both
      `:tags` and `:field` in the component assigns and notifies the parent LiveView:

          send(self(), {__MODULE__, {:tags_updated, id, tags}})

    * **Max tags** – when `length(tags) >= max_tags`, the input becomes disabled
      and additional tags cannot be added.

    * **Autocomplete** – suggestions are filtered by the current input value;
      clicking a suggestion behaves the same as adding a tag manually.

    * **Error handling** – validation failures set an error message, which is
      cleared on the next successful change or when the input is edited.
  """
  use UiWebWeb, :live_component

  attr :id, :string,
    required: true,
    doc: "Unique component ID (used for DOM id and message routing)."

  attr :field, :map,
    required: true,
    doc: """
    Form field map with at least `:name` (string) and `:value` (list of tags or nil).

    Usually this is `form[:tags]` from a Phoenix form (`Phoenix.HTML.FormField`-compatible map).
    """

  attr :suggestions, :list,
    default: [],
    doc: "List of suggested tags used for autocomplete."

  attr :max_tags, :integer,
    default: 20,
    doc: "Maximum number of tags allowed. When reached, the input becomes disabled."

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:current_input, "")
     |> assign(:filtered_suggestions, [])
     |> assign(:show_suggestions, false)
     |> assign(:error_message, nil)}
  end

  @impl true
  def update(%{field: field} = assigns, socket) do
    # Always extract tags from assigns.field.value, never from socket.assigns.tags
    tags =
      case field do
        %{value: value} when is_list(value) ->
          value

        %{value: value} when is_binary(value) ->
          # If value is a string, parse it
          parse_tags(value)

        _ ->
          []
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:tags, tags)}
  end

  def update(assigns, socket) do
    # Fallback if field is missing - assign empty tags
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:tags, [])}
  end

  @impl true
  def handle_event("input_change", %{"value" => value}, socket) do
    # Filter suggestions based on input
    filtered =
      if String.length(value) > 0 do
        socket.assigns.suggestions
        |> Enum.filter(fn suggestion ->
          String.contains?(String.downcase(suggestion), String.downcase(value))
        end)
        |> Enum.reject(fn suggestion ->
          Enum.member?(socket.assigns.tags, suggestion)
        end)
        |> Enum.take(5)
      else
        []
      end

    socket =
      socket
      |> assign(:current_input, value)
      |> assign(:filtered_suggestions, filtered)
      |> assign(:show_suggestions, length(filtered) > 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_tag", %{"value" => value}, socket) do
    tag = String.trim(value)

    cond do
      tag == "" ->
        {:noreply, socket}

      Enum.member?(socket.assigns.tags, tag) ->
        {:noreply, assign(socket, :error_message, "Tag already exists")}

      length(socket.assigns.tags) >= socket.assigns.max_tags ->
        {:noreply,
         assign(socket, :error_message, "Maximum #{socket.assigns.max_tags} tags allowed")}

      !valid_tag?(tag) ->
        {:noreply, assign(socket, :error_message, "Tag must be alphanumeric with hyphens")}

      true ->
        new_tags = socket.assigns.tags ++ [tag]

        {:noreply,
         socket
         |> put_tags(new_tags)
         |> assign(:current_input, "")
         |> assign(:show_suggestions, false)}
    end
  end

  @impl true
  def handle_event("add_tag_on_key", %{"key" => key, "value" => value}, socket) do
    # Enter or Comma adds tag
    if key in ["Enter", ","] do
      handle_event("add_tag", %{"value" => value}, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    new_tags = Enum.reject(socket.assigns.tags, &(&1 == tag))

    {:noreply, put_tags(socket, new_tags)}
  end

  @impl true
  def handle_event("remove_last_on_backspace", %{"key" => "Backspace", "value" => ""}, socket) do
    # Backspace on empty input removes last tag
    if length(socket.assigns.tags) > 0 do
      new_tags = Enum.drop(socket.assigns.tags, -1)
      {:noreply, put_tags(socket, new_tags)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_suggestion", %{"tag" => tag}, socket) do
    handle_event("add_tag", %{"value" => tag}, socket)
  end

  @impl true
  def handle_event("hide_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  # Private helpers

  defp put_tags(socket, tags, notify? \\ true) do
    socket =
      socket
      |> assign(:tags, tags)
      |> assign(:field, %{socket.assigns.field | value: tags})
      |> assign(:error_message, nil)

    if notify? do
      notify_parent(socket, tags)
    end

    socket
  end

  defp parse_tags(tags) when is_list(tags), do: tags
  defp parse_tags(tags) when is_binary(tags) do
    tags
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
  defp parse_tags(_), do: []

  defp get_field_name(field) when is_struct(field) do
    # Phoenix.HTML.FormField - get name from field
    Map.get(field, :name) || to_string(Map.get(field, :field, ""))
  end
  defp get_field_name(field) when is_map(field) do
    # Plain map - get name directly
    Map.get(field, :name) || Map.get(field, "name") || "tags"
  end
  defp get_field_name(_), do: "tags"

  defp valid_tag?(tag) do
    Regex.match?(~r/^[a-z0-9-]+$/i, tag) and String.length(tag) <= 30
  end

  defp notify_parent(socket, tags) do
    # In LiveComponent, self() is the LiveView process (same process)
    # Use canonical pattern: send(self(), {__MODULE__, msg})
    send(self(), {__MODULE__, {:tags_updated, socket.assigns.id, tags}})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="tags-input-component" id={@id}>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        Tags
        <span class="text-gray-500 font-normal">
          (<%= length(@tags) %>/<%= @max_tags %>)
        </span>
      </label>

      <!-- Tags Display Area -->
      <div class={["border rounded-md p-2 min-h-[42px] focus-within:ring-2 focus-within:border-indigo-500", 
                   if(@error_message, do: "border-red-300 focus-within:border-red-500 focus-within:ring-red-500", else: "border-gray-300 focus-within:ring-indigo-500")]}>
        <div class="flex flex-wrap gap-2 items-center" data-role="tags-container">
          <!-- Existing tags -->
          <%= for tag <- @tags do %>
            <span class="inline-flex items-center gap-1 px-2 py-1 rounded-md text-sm font-medium bg-indigo-100 text-indigo-800">
              <%= tag %>
              <button
                type="button"
                phx-click="remove_tag"
                phx-value-tag={tag}
                phx-target={@myself}
                class="text-indigo-600 hover:text-indigo-900 focus:outline-none"
                aria-label={"Remove #{tag}"}
              >
                <svg class="h-3 w-3" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
            </span>
          <% end %>

          <!-- Input field -->
          <input
            type="text"
            value={@current_input}
            phx-change="input_change"
            phx-keydown="add_tag_on_key"
            phx-keyup="remove_last_on_backspace"
            phx-blur="hide_suggestions"
            phx-target={@myself}
            placeholder={if length(@tags) == 0, do: "Type and press Enter...", else: ""}
            class="flex-1 min-w-[120px] border-0 p-0 focus:ring-0 focus:outline-none text-sm"
            disabled={length(@tags) >= @max_tags}
          />
        </div>
      </div>

      <!-- Autocomplete Suggestions Dropdown -->
      <%= if @show_suggestions and length(@filtered_suggestions) > 0 do %>
        <div class="relative mt-1">
          <div class="absolute z-10 w-full bg-white shadow-lg rounded-md border border-gray-200 max-h-60 overflow-auto" data-role="autocomplete-list">
            <%= for suggestion <- @filtered_suggestions do %>
              <div data-role="autocomplete-item">
                <button
                  type="button"
                  phx-click="add_suggestion"
                  phx-value-tag={suggestion}
                  phx-target={@myself}
                  class="w-full text-left px-4 py-2 text-sm hover:bg-indigo-50 focus:bg-indigo-50 focus:outline-none"
                >
                  <%= suggestion %>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Popular Tags (quick add) -->
      <%= if length(@tags) < @max_tags do %>
        <div class="mt-2 text-sm text-gray-600" data-role="popular-tags">
          <span class="font-medium">Popular:</span>
          <%= for suggestion <- Enum.take(@suggestions, 8) do %>
            <%= if not Enum.member?(@tags, suggestion) do %>
              <button
                type="button"
                phx-click="add_suggestion"
                phx-value-tag={suggestion}
                phx-target={@myself}
                class="ml-2 text-indigo-600 hover:text-indigo-900 hover:underline"
                data-role="popular-tag"
              >
                #<%= suggestion %>
              </button>
            <% end %>
          <% end %>
        </div>
      <% end %>

      <!-- Hidden input for form submission -->
      <input
        type="hidden"
        name={get_field_name(@field)}
        value={Jason.encode!(@tags)}
      />

      <!-- Error message -->
      <%= if @error_message do %>
        <p class="mt-1 text-xs text-red-600" data-role="error-message"><%= @error_message %></p>
      <% end %>

      <!-- Help text -->
      <p class={["mt-1 text-xs", if(@error_message, do: "text-red-500", else: "text-gray-500")]}>
        Press Enter or comma to add. Backspace to remove last. Max <%= @max_tags %> tags.
      </p>
    </div>
    """
  end
end

