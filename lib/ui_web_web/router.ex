defmodule UiWebWeb.Router do
  use UiWebWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {UiWebWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug UiWeb.Auth.Pipeline
    plug Guardian.Plug.EnsureAuthenticated
    plug :load_current_user
  end

  scope "/", UiWebWeb do
    pipe_through :browser
    get "/", PageController, :home
    get "/login", AuthController, :login
    
    # Dev login for E2E tests (only in test/dev)
    if Mix.env() in [:test, :dev] do
      get "/dev-login", DevLoginController, :login
    end
  end

  scope "/app", UiWebWeb do
    pipe_through [:browser, :auth]
    live "/dashboard", DashboardLive, :index
    live "/messages", MessagesLive.Index, :index
    live "/messages/new", MessagesLive.Form, :new
    live "/messages/:id", MessagesLive.Show, :show
    live "/messages/:id/edit", MessagesLive.Form, :edit
    live "/policies", PoliciesLive, :index
    live "/extensions", ExtensionsLive.Index, :index
    live "/extensions/new", ExtensionsLive.Form, :new
    live "/extensions/:id/edit", ExtensionsLive.Form, :edit
    live "/extensions/pipeline", ExtensionsPipelineLive, :index
  end

  # Load current user from Guardian token
  defp load_current_user(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn

      user ->
        assign(conn, :current_user, user)
    end
  end

  if Application.compile_env(:ui_web, :oidc_enabled, false) do
    scope "/auth", UiWebWeb do
      pipe_through :browser
      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
      post "/:provider/callback", AuthController, :callback
      get "/logout", AuthController, :logout
    end
  end

  if Application.compile_env(:ui_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: {UiWebWeb.Telemetry, :metrics}
    end
  end

  # Test routes (only in test environment)
  if Mix.env() == :test do
    scope "/test", UiWebWeb.Components.TagsInputTest do
      pipe_through [:browser]
      live "/", TestTagsInputLiveView, :index, as: :test_tags_input
    end
  end
end
