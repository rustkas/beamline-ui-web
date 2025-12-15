import Config

# Do not print debug messages in production
config :logger, level: :info

# Configure endpoint for production
config :ui_web, UiWebWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
