# 🧪 Integration Testing Guide: UI-Web ↔ Gateway

**Created**: 2025-11-22  
**Purpose**: Comprehensive guide for integration testing between UI-Web (Phoenix) and C-Gateway (C++)

---

## 🎯 Architecture Overview

```
┌─────────────┐         HTTP/REST         ┌──────────────┐
│             │ ←─────────────────────→  │              │
│  UI-Web     │      + SSE Streaming      │  C-Gateway   │
│  (Phoenix)  │                           │  (C++)       │
│  Port 4000  │                           │  Port 8080   │
└─────────────┘                           └──────────────┘
      │                                          │
      │                                          │
      └────────── Integration Testing ──────────┘
```

**Key Components**:
- **UI-Web**: Phoenix LiveView на Elixir (localhost:4000)
- **C-Gateway**: C++ HTTP Gateway (localhost:8080)
- **Communication**: REST API + SSE streaming

---

## ⚠️ Критические Проблемы и Решения

### 🔴 Проблема 1: Gateway Not Running

**Симптомы**:
```
14:36:26.335 [warning] SSEBridge connect error: %Mint.TransportError{reason: :econnrefused}
14:36:26.461 [warning] retry: got exception, will retry in 100ms, 3 attempts left
14:36:26.471 [warning] ** (Req.TransportError) connection refused
```

**Причина**: C-Gateway не запущен или недоступен на localhost:8080

**Решение A: Запустить C-Gateway локально**

```bash
# 1. Перейти в директорию C-Gateway
cd /home/rustkas/aigroup/apps/c-gateway

# 2. Собрать проект
make build

# 3. Запустить Gateway
./build/gateway --port 8080

# 4. Проверить здоровье
curl http://localhost:8080/health
```

**Решение B: Mock Gateway для тестов**

```elixir
# test/support/mock_gateway.ex
defmodule UiWeb.Test.MockGateway do
  use Plug.Router
  
  plug :match
  plug :dispatch
  
  # Health endpoint
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{
      status: "ok",
      nats: %{connected: true},
      timestamp_ms: System.system_time(:millisecond)
    }))
  end
  
  # Metrics endpoint
  get "/metrics" do
    send_resp(conn, 200, Jason.encode!(%{
      rps: 100,
      latency: %{p50: 10, p95: 50, p99: 100},
      error_rate: 0.01
    }))
  end
  
  # Messages endpoints
  get "/api/v1/messages" do
    send_resp(conn, 200, Jason.encode!(%{items: []}))
  end
  
  post "/api/v1/messages" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    {:ok, data} = Jason.decode(body)
    
    send_resp(conn, 200, Jason.encode!(%{
      message_id: "msg_#{:os.system_time(:millisecond)}",
      ack_timestamp_ms: :os.system_time(:millisecond),
      status: "published"
    }))
  end
end
```

**Использование Mock в тестах**:

```elixir
# test/test_helper.exs
# Запустить Mock Gateway на 8081
{:ok, _} = Plug.Cowboy.http(UiWeb.Test.MockGateway, [], port: 8081)

# Переопределить конфигурацию для тестов
Application.put_env(:ui_web, :gateway, url: "http://localhost:8081")
```

---

### 🔴 Проблема 2: API Contract Mismatch

**Симптомы**:
- 404 Not Found на endpoints
- Неожиданные поля в JSON
- Type mismatches

**Причина**: Несоответствие между UI-Web и Gateway API контрактами

**Решение: Contract Testing**

```elixir
# test/ui_web/integration/gateway_contract_test.exs
defmodule UiWeb.Integration.GatewayContractTest do
  use ExUnit.Case
  alias UiWeb.Services.GatewayClient
  
  @tag :integration
  test "health endpoint returns valid schema" do
    assert {:ok, health} = GatewayClient.fetch_health()
    
    # Validate required fields
    assert is_binary(health["status"])
    assert is_map(health["nats"])
    assert is_integer(health["timestamp_ms"])
  end
  
  @tag :integration
  test "metrics endpoint returns valid schema" do
    assert {:ok, metrics} = GatewayClient.fetch_metrics()
    
    # Validate structure
    assert is_number(metrics["rps"]) or is_nil(metrics["rps"])
    assert is_map(metrics["latency"])
    assert is_number(metrics["error_rate"]) or is_nil(metrics["error_rate"])
  end
  
  @tag :integration
  test "POST /api/v1/messages accepts CreateMessageDto" do
    message = %{
      "tenant_id" => "test_tenant",
      "message_type" => "chat",
      "payload" => Jason.encode!(%{text: "test"}),
      "trace_id" => "trace_#{:os.system_time()}"
    }
    
    assert {:ok, ack} = GatewayClient.post_json("/api/v1/messages", message)
    assert is_binary(ack["message_id"])
    assert is_integer(ack["ack_timestamp_ms"])
    assert ack["status"] == "published"
  end
end
```

**Запуск contract tests**:

```bash
# Только integration тесты (требуют запущенный Gateway)
mix test --only integration

# Пропустить integration тесты
mix test --exclude integration
```

---

### 🔴 Проблема 3: SSE Streaming Connection Issues

**Симптомы**:
```
SSEBridge connect error: timeout
No events received from Gateway
```

**Причина**: SSE endpoint не работает или таймаут соединения

**Решение: SSE Testing Strategy**

```elixir
# test/ui_web/integration/sse_bridge_test.exs
defmodule UiWeb.Integration.SSEBridgeTest do
  use ExUnit.Case
  alias UiWeb.SSEBridge
  
  @tag :integration
  @tag timeout: 30_000
  test "SSEBridge connects to Gateway and receives events" do
    # Start SSEBridge
    gateway_url = Application.get_env(:ui_web, :gateway)[:url]
    tenant_id = "test_tenant"
    
    {:ok, pid} = SSEBridge.start_link(gateway: gateway_url, tenant: tenant_id)
    
    # Subscribe to events
    topic = "messages:#{tenant_id}"
    :ok = Phoenix.PubSub.subscribe(UiWeb.PubSub, topic)
    
    # Send test message via Gateway
    message = %{
      "tenant_id" => tenant_id,
      "message_type" => "chat",
      "payload" => Jason.encode!(%{text: "SSE test"}),
      "trace_id" => "sse_test_#{:os.system_time()}"
    }
    
    {:ok, _ack} = GatewayClient.post_json("/api/v1/messages", message)
    
    # Wait for SSE event
    assert_receive %Phoenix.Socket.Broadcast{
      event: "message_event",
      payload: %{"event" => "message_created"}
    }, 5_000
    
    # Cleanup
    GenServer.stop(pid)
  end
end
```

**SSE Mock для Unit Tests**:

```elixir
# test/support/sse_mock_server.ex
defmodule UiWeb.Test.SSEMockServer do
  use Plug.Router
  
  plug :match
  plug :dispatch
  
  get "/api/v1/messages/stream" do
    conn = put_resp_header(conn, "content-type", "text/event-stream")
    conn = put_resp_header(conn, "cache-control", "no-cache")
    conn = send_chunked(conn, 200)
    
    # Send test events
    events = [
      "event: message_created\n",
      "data: {\"message_id\":\"msg_123\",\"tenant_id\":\"test\"}\n\n",
      "event: message_updated\n",
      "data: {\"message_id\":\"msg_123\",\"status\":\"processed\"}\n\n"
    ]
    
    Enum.each(events, fn event ->
      {:ok, conn} = chunk(conn, event)
      Process.sleep(100)
    end)
    
    conn
  end
end
```

---

### 🔴 Проблема 4: Authentication & CORS

**Симптомы**:
- 401 Unauthorized
- CORS preflight failures
- Session issues

**Причина**: Gateway может требовать аутентификацию или CORS не настроен

**Решение A: Bypass Auth для Dev/Test**

```elixir
# config/test.exs
config :ui_web, :gateway,
  url: "http://localhost:8081",  # Mock Gateway
  timeout: 5_000,
  auth_enabled: false  # Отключить auth для тестов
```

**Решение B: Mock JWT Tokens**

```elixir
# test/support/auth_helpers.ex
defmodule UiWeb.Test.AuthHelpers do
  def create_test_token do
    claims = %{
      "sub" => "test_user",
      "tenant_id" => "test_tenant",
      "exp" => System.system_time(:second) + 3600
    }
    
    {:ok, token, _claims} = UiWeb.Auth.Guardian.encode_and_sign(
      %{id: "test_user"},
      claims
    )
    
    token
  end
  
  def auth_conn(conn) do
    token = create_test_token()
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
```

**Решение C: Gateway CORS Configuration**

```c++
// apps/c-gateway/src/cors_middleware.cpp
void setup_cors(HttpServer& server) {
  server.add_middleware([](Request& req, Response& res, NextFunction& next) {
    res.set_header("Access-Control-Allow-Origin", "*");
    res.set_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    res.set_header("Access-Control-Allow-Headers", "Content-Type, Authorization");
    
    if (req.method() == "OPTIONS") {
      res.status(204).end();
    } else {
      next();
    }
  });
}
```

---

### 🔴 Проблема 5: Environment Configuration

**Симптомы**:
- Tests fail in CI but pass locally
- Configuration mismatches
- Timeouts different between envs

**Причина**: Разные конфигурации для dev/test/ci

**Решение: Environment-specific Config**

```elixir
# config/test.exs
import Config

config :ui_web, UiWebWeb.Endpoint,
  http: [port: 4002],
  server: false

config :ui_web, :gateway,
  url: System.get_env("GATEWAY_URL") || "http://localhost:8081",
  timeout: String.to_integer(System.get_env("GATEWAY_TIMEOUT") || "5000")

config :ui_web, :oidc_enabled, false

# Отключить SSEBridge для unit tests
config :ui_web, :sse_enabled, false
```

**CI Configuration**:

```yaml
# .github/workflows/integration-test.yml
name: Integration Tests

on: [push, pull_request]

jobs:
  integration:
    runs-on: ubuntu-latest
    
    services:
      # Mock Gateway service
      gateway:
        image: nginx:alpine
        ports:
          - 8081:80
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      
      - name: Install dependencies
        run: cd apps/ui_web && mix deps.get
      
      - name: Run integration tests
        env:
          GATEWAY_URL: http://localhost:8081
          MIX_ENV: test
        run: cd apps/ui_web && mix test --only integration
```

---

### 🔴 Проблема 6: Timing & Race Conditions

**Симптомы**:
- Flaky tests
- Random failures
- Timeout errors

**Причина**: Асинхронные операции, network latency

**Решение: Proper Async Testing**

```elixir
# test/ui_web/integration/async_test.exs
defmodule UiWeb.Integration.AsyncTest do
  use ExUnit.Case
  
  @tag :integration
  test "wait for async operations with proper timeout" do
    # Start async operation
    task = Task.async(fn ->
      GatewayClient.post_json("/api/v1/messages", %{...})
    end)
    
    # Wait with timeout
    assert {:ok, result} = Task.await(task, 10_000)
  end
  
  @tag :integration
  test "use eventually pattern for async assertions" do
    # Trigger async event
    {:ok, _} = GatewayClient.post_json("/api/v1/messages", %{...})
    
    # Wait for event with retries
    eventually(fn ->
      {:ok, messages} = GatewayClient.get_json("/api/v1/messages")
      assert length(messages["items"]) > 0
    end, timeout: 5_000, interval: 100)
  end
  
  defp eventually(assertion_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    interval = Keyword.get(opts, :interval, 100)
    deadline = System.monotonic_time(:millisecond) + timeout
    
    do_eventually(assertion_fn, deadline, interval)
  end
  
  defp do_eventually(assertion_fn, deadline, interval) do
    try do
      assertion_fn.()
    rescue
      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(interval)
          do_eventually(assertion_fn, deadline, interval)
        else
          assertion_fn.()  # Final attempt, will raise if fails
        end
    end
  end
end
```

---

### 🔴 Проблема 7: Test Data Management

**Симптомы**:
- Data pollution between tests
- Non-deterministic results
- Cleanup issues

**Причина**: Shared state, no proper cleanup

**Решение: Test Fixtures & Cleanup**

```elixir
# test/support/fixtures.ex
defmodule UiWeb.Test.Fixtures do
  def message_fixture(attrs \\ %{}) do
    defaults = %{
      "tenant_id" => "test_tenant_#{:rand.uniform(1000)}",
      "message_type" => "chat",
      "payload" => Jason.encode!(%{text: "test"}),
      "trace_id" => "trace_#{:os.system_time()}"
    }
    
    Map.merge(defaults, attrs)
  end
  
  def create_test_message(attrs \\ %{}) do
    message = message_fixture(attrs)
    {:ok, ack} = GatewayClient.post_json("/api/v1/messages", message)
    {message, ack}
  end
  
  def cleanup_test_messages(tenant_id) do
    # Delete all test messages for tenant
    {:ok, messages} = GatewayClient.get_json("/api/v1/messages?tenant_id=#{tenant_id}")
    
    Enum.each(messages["items"], fn msg ->
      GatewayClient.delete("/api/v1/messages/#{msg["message_id"]}")
    end)
  end
end
```

**Usage in tests**:

```elixir
defmodule UiWeb.Integration.MessagesTest do
  use ExUnit.Case
  import UiWeb.Test.Fixtures
  
  setup do
    tenant_id = "test_#{:rand.uniform(1000)}"
    
    on_exit(fn ->
      cleanup_test_messages(tenant_id)
    end)
    
    {:ok, tenant_id: tenant_id}
  end
  
  @tag :integration
  test "create and retrieve message", %{tenant_id: tenant_id} do
    {message, ack} = create_test_message(%{"tenant_id" => tenant_id})
    
    assert {:ok, retrieved} = GatewayClient.get_json("/api/v1/messages/#{ack["message_id"]}")
    assert retrieved["tenant_id"] == tenant_id
  end
end
```

---

## 🚀 Recommended Testing Strategy

### Level 1: Unit Tests (Fast, No Gateway)

```bash
# Run unit tests only (with mocks)
mix test --exclude integration
```

**Coverage**:
- GatewayClient logic (with Req mocks)
- LiveView rendering
- Form validations
- Helper functions

### Level 2: Integration Tests (Slow, Requires Gateway)

```bash
# Run with local Gateway
mix test --only integration

# Or with mock Gateway
GATEWAY_URL=http://localhost:8081 mix test --only integration
```

**Coverage**:
- Real HTTP requests
- SSE streaming
- End-to-end flows
- Contract validation

### Level 3: E2E Tests (Very Slow, Full Stack)

```bash
# Run full E2E with real Gateway + NATS + Router
./scripts/run_e2e_tests.sh
```

**Coverage**:
- Full user journeys
- Browser automation (Wallaby)
- Real authentication flow
- Multi-service orchestration

---

## 📋 Integration Testing Checklist

### Before Testing

- [ ] C-Gateway built and ready (`make build`)
- [ ] Gateway configuration correct (`config/dev.exs`)
- [ ] Network connectivity verified
- [ ] Test fixtures prepared

### During Testing

- [ ] Mock Gateway for unit tests
- [ ] Real Gateway for integration tests
- [ ] Proper test isolation (unique tenant IDs)
- [ ] Cleanup after each test
- [ ] Timeout handling
- [ ] Error scenarios covered

### After Testing

- [ ] Test coverage report generated
- [ ] Integration test results documented
- [ ] Known issues logged
- [ ] CI pipeline configured

---

## 🔧 Useful Commands

```bash
# Start Mock Gateway for tests
mix run test/support/start_mock_gateway.exs

# Run only integration tests
mix test --only integration

# Run with verbose output
mix test --trace --only integration

# Check test coverage
mix test --cover

# Run specific integration test file
mix test test/ui_web/integration/gateway_contract_test.exs

# Debug integration test
iex -S mix test --trace test/ui_web/integration/sse_bridge_test.exs
```

---

## 📊 Success Metrics

**Target Coverage**:
- Unit tests: 80%+
- Integration tests: 60%+
- E2E tests: Critical paths only

**Performance Targets**:
- Unit tests: < 5 seconds
- Integration tests: < 30 seconds
- E2E tests: < 2 minutes

**Quality Targets**:
- Zero flaky tests
- All contracts validated
- Full error scenarios covered
- Documentation complete

---

## 🎯 Next Steps

1. **Implement Mock Gateway** (1 hour)
2. **Write Contract Tests** (2 hours)
3. **Add SSE Integration Tests** (2 hours)
4. **Setup CI Pipeline** (1 hour)
5. **Document Known Issues** (30 min)

**Total Estimated Time**: 6.5 hours for complete integration testing setup

---

**Last Updated**: 2025-11-22  
**Status**: Ready for Implementation  
**Owner**: UI-Web Team
