import Config

# Gateway Configuration
config :ui_web, :gateway,
  url: System.get_env("GATEWAY_URL", "http://localhost:8081"),
  timeout: String.to_integer(System.get_env("GATEWAY_TIMEOUT_MS", "10000")),
  retry_attempts: String.to_integer(System.get_env("GATEWAY_RETRY_ATTEMPTS", "3")),
  health_check_interval: String.to_integer(System.get_env("GATEWAY_HEALTH_CHECK_MS", "30000"))

# NATS Configuration (for real-time)
config :ui_web, :nats,
  url: System.get_env("NATS_URL", "nats://localhost:4222"),
  enabled: System.get_env("NATS_ENABLED", "true") == "true"

# Feature Flags
config :ui_web, :features,
  use_mock_gateway: System.get_env("USE_MOCK_GATEWAY", "false") == "true",
  enable_real_time: System.get_env("ENABLE_REAL_TIME", "true") == "true"

if config_env() == :prod do
  # Production overrides
  config :ui_web, :gateway,
    url: System.fetch_env!("GATEWAY_URL")

  config :ui_web, :nats,
    url: System.fetch_env!("NATS_URL")
end
