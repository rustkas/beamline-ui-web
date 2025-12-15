# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ui_web,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :ui_web, UiWebWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: UiWebWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: UiWeb.PubSub,
  live_view: [signing_salt: "7sHN2O9I"]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :ui_web, UiWeb.Auth.Guardian,
  issuer: "ui_web",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "dev-only-secret-key"

config :ueberauth, Ueberauth,
  providers: [
    oidc:
      {Ueberauth.Strategy.OIDC,
       [
         provider: :oidc,
         client_id: System.get_env("OIDC_CLIENT_ID") || "dev-client-id",
         client_secret: System.get_env("OIDC_CLIENT_SECRET") || "dev-client-secret",
         discovery_document_uri:
           System.get_env("OIDC_DISCOVERY_URL") ||
             "https://accounts.google.com/.well-known/openid-configuration",
         redirect_uri:
           System.get_env("OIDC_REDIRECT_URI") || "http://localhost:4000/auth/oidc/callback",
         response_type: "code",
         scope: "openid profile email"
       ]}
  ]

config :esbuild, :version, "0.25.0"
config :tailwind, :version, "3.4.10"

config :esbuild,
  ui_web: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  ui_web: [
    args: ~w(--input=css/app.css --output=../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]
