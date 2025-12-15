import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ui_web, UiWebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "WPM5po2IutSOqHAoLNzKOa1vDEnDH8s3q/RTAPmDIazNRlUce/IQbUuHphGMZo4J",
  server: false

# Gateway client configuration for tests
config :ui_web, :gateway,
  url: System.get_env("GATEWAY_URL") || "http://localhost:8082",
  timeout: String.to_integer(System.get_env("GATEWAY_TIMEOUT") || "5000")

# Disable SSE Bridge for unit tests
config :ui_web, :sse_enabled, false

# Disable OIDC for tests
config :ui_web, :oidc_enabled, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
