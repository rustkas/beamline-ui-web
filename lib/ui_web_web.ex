defmodule UiWebWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use UiWebWeb, :controller
      use UiWebWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # HTML helpers
      import Phoenix.HTML
      alias Phoenix.LiveView.JS
      import UiWebWeb.CoreComponents
      import UiWebWeb.Components.URLPreviewComponent, only: [url_preview: 1]
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {UiWebWeb.Layouts, :app}

      # Include the same HTML helpers as regular components so
      # function components like <.simple_form> / <.input> are available
      import Phoenix.HTML
      alias Phoenix.LiveView.JS
      import UiWebWeb.CoreComponents
      import UiWebWeb.Components.URLPreviewComponent, only: [url_preview: 1]

      unquote(verified_routes())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      # Include the same HTML helpers as regular components
      import Phoenix.HTML
      alias Phoenix.LiveView.JS
      import UiWebWeb.CoreComponents

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: UiWebWeb.Endpoint,
        router: UiWebWeb.Router,
        statics: UiWebWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
