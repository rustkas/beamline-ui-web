defmodule UiWebWeb.CoreComponents do
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: UiWebWeb.Endpoint,
    router: UiWebWeb.Router,
    statics: UiWebWeb.static_paths()

  attr :flash, :map, default: %{}

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group">
      <%= for {type, msg} <- @flash do %>
        <div class={"rounded-md p-3 mb-2 text-sm " <> flash_class(type)}><%= msg %></div>
      <% end %>
    </div>
    """
  end

  defp flash_class("info"), do: "bg-blue-50 text-blue-700"
  defp flash_class("error"), do: "bg-red-50 text-red-700"
  defp flash_class(_), do: "bg-gray-50 text-gray-700"

  attr :id, :string, required: true, doc: "Modal ID"
  attr :show, :boolean, default: false, doc: "Show modal"
  slot :inner_block, required: true
  slot :title

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-50 overflow-y-auto hidden"
      phx-remove={hide_modal(@id)}
    >
      <div class="flex items-center justify-center min-h-screen px-4">
        <div
          class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
          phx-click-away={hide_modal(@id)}
        ></div>
        <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full p-6 relative z-10">
          <%= if @title != [] do %>
            <div class="mb-4">
              <h3 class="text-lg font-semibold"><%= render_slot(@title) %></h3>
            </div>
          <% end %>
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  defp hide_modal(id) do
    JS.hide(to: "##{id}")
  end
end
