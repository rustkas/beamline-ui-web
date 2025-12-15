import Config

# Integration Test Configuration for UI-Web ↔ Gateway

# Gateway Configuration
config :ui_web, :gateway,
  url: System.get_env("GATEWAY_URL", "http://localhost:8081"),
  timeout: String.to_integer(System.get_env("GATEWAY_TIMEOUT", "5000")),
  retry_attempts: String.to_integer(System.get_env("GATEWAY_RETRY_ATTEMPTS", "3")),
  retry_delay: String.to_integer(System.get_env("GATEWAY_RETRY_DELAY", "1000"))

# Test Tenant Configuration
config :ui_web, :test_tenant,
  id: System.get_env("TEST_TENANT_ID", "integration_test"),
  name: System.get_env("TEST_TENANT_NAME", "Integration Test Tenant")

# SSE Configuration for Tests
config :ui_web, :sse_test,
  connect_timeout: String.to_integer(System.get_env("SSE_CONNECT_TIMEOUT", "5000")),
  receive_timeout: String.to_integer(System.get_env("SSE_RECEIVE_TIMEOUT", "2000")),
  max_events_per_test: String.to_integer(System.get_env("SSE_MAX_EVENTS", "10"))

# Performance Test Configuration
config :ui_web, :performance_test,
  concurrent_requests: String.to_integer(System.get_env("PERF_CONCURRENT_REQUESTS", "10")),
  total_requests: String.to_integer(System.get_env("PERF_TOTAL_REQUESTS", "100")),
  ramp_up_time: String.to_integer(System.get_env("PERF_RAMP_UP_TIME", "5000")),
  max_response_time: String.to_integer(System.get_env("PERF_MAX_RESPONSE_TIME", "2000"))

# Test Data Configuration
config :ui_web, :test_data,
  cleanup_after_tests: System.get_env("CLEANUP_AFTER_TESTS", "true") == "true",
  use_mock_gateway: System.get_env("USE_MOCK_GATEWAY", "false") == "true",
  mock_gateway_port: String.to_integer(System.get_env("MOCK_GATEWAY_PORT", "8082"))

# Logging Configuration for Tests
config :logger, :console,
  level: String.to_atom(System.get_env("TEST_LOG_LEVEL", "info")),
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :tenant_id]

# ExUnit Configuration
config :ex_unit,
  assert_receive_timeout: String.to_integer(System.get_env("EXUNIT_ASSERT_TIMEOUT", "2000")),
  refute_receive_timeout: String.to_integer(System.get_env("EXUNIT_REFUTE_TIMEOUT", "500"))

# Environment-specific overrides
if System.get_env("CI") == "true" do
  # CI/CD environment settings
  config :ui_web, :gateway,
    url: System.get_env("CI_GATEWAY_URL", "http://gateway:8080"),
    timeout: 10_000,
    retry_attempts: 5

  config :ex_unit,
    assert_receive_timeout: 10_000,
    refute_receive_timeout: 2_000

  config :logger, :console, level: :warn
end

if System.get_env("STRESS_TEST") == "true" do
  # Stress test configuration
  config :ui_web, :performance_test,
    concurrent_requests: 50,
    total_requests: 1000,
    ramp_up_time: 10_000,
    max_response_time: 5000

  config :ex_unit,
    assert_receive_timeout: 30_000,
    refute_receive_timeout: 5_000
end
