# Start Mock Gateway for tests (if not already running)
if System.get_env("GATEWAY_URL") != "http://localhost:8082" do
  case UiWeb.Test.MockGatewayServer.start(port: 8082) do
    {:ok, _pid} ->
      IO.puts("✅ Mock Gateway started on port 8082")

    {:error, reason} ->
      IO.warn("⚠️  Failed to start Mock Gateway: #{inspect(reason)}")
  end
end

# Start Mock Router for E2E tests (optional, only if NATS is available)
if System.get_env("ENABLE_MOCK_ROUTER") == "true" do
  case UiWeb.Test.MockRouter.start() do
    {:ok, _pid} ->
      IO.puts("✅ Mock Router started (NATS: #{System.get_env("NATS_URL") || "nats://localhost:4222"})")

    {:error, reason} ->
      IO.warn("⚠️  Failed to start Mock Router: #{inspect(reason)} (NATS may not be available)")
  end
end

# Override Gateway configuration for tests
Application.put_env(:ui_web, :gateway, [
  url: System.get_env("GATEWAY_URL") || "http://localhost:8082",
  timeout: String.to_integer(System.get_env("GATEWAY_TIMEOUT") || "5000")
])

ExUnit.start()
