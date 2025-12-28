# Mock Router for E2E Tests

**Status:** ✅ **COMPLETE**

Mock Router provides a stable NATS responder for E2E tests, allowing end-to-end CP1 flow testing without requiring a real Router instance.

---

## 🎯 Purpose

The Mock Router enables:
- **End-to-end CP1 testing** without real Router infrastructure
- **Predictable RouteDecision generation** for consistent test results
- **Stable NATS responder** that handles `beamline.router.v1.decide` requests
- **Configurable responses** based on request parameters

---

## 📋 Features

### RouteDecision Generation

The Mock Router generates predictable RouteDecision responses based on request parameters:

**Default Values:**
- Provider: `"openai:gpt-4o"`
- Priority: `50`
- Expected Latency: `850` ms
- Expected Cost: `0.012`
- Reason: `"best_score"`

**Special Cases:**

| Condition | Result |
|-----------|--------|
| `task.type` contains `"fail"` | Error response |
| `tenant_id == "slow_tenant"` | Latency: `2000` ms |
| `tenant_id == "fast_tenant"` | Latency: `300` ms |
| `tenant_id == "expensive_tenant"` | Cost: `0.05` |
| `tenant_id == "cheap_tenant"` | Cost: `0.001` |
| `tenant_id == "tenant_anthropic"` | Provider: `"anthropic:claude-3-opus"` |
| `tenant_id == "tenant_google"` | Provider: `"google:gemini-pro"` |

---

## 🚀 Usage

### Starting Mock Router

**In test_helper.exs (automatic):**
```elixir
# Set environment variable to enable
ENABLE_MOCK_ROUTER=true mix test
```

**Manually:**
```elixir
{:ok, pid} = UiWeb.Test.MockRouter.start()
```

**With custom NATS URL:**
```elixir
{:ok, pid} = UiWeb.Test.MockRouter.start(nats_url: "nats://nats:4222")
```

### Stopping Mock Router

```elixir
UiWeb.Test.MockRouter.stop()
```

### Checking Status

```elixir
UiWeb.Test.MockRouter.running?()  # => true | false
```

---

## 📡 NATS Integration

### Subject

The Mock Router subscribes to:
```
beamline.router.v1.decide
```

### Request Format

```json
{
  "version": "1",
  "tenant_id": "acme",
  "request_id": "req-123",
  "trace_id": "tr-456",
  "task": {
    "type": "text.generate",
    "payload": "...",
    "payload_ref": "s3://bucket/key"
  },
  "policy_id": "policy:default",
  "constraints": {
    "max_latency_ms": 2000
  },
  "metadata": {
    "user_id": "u-42"
  }
}
```

### Response Format (Success)

```json
{
  "ok": true,
  "decision": {
    "provider_id": "openai:gpt-4o",
    "priority": 50,
    "expected_latency_ms": 850,
    "expected_cost": 0.012,
    "reason": "best_score"
  },
  "context": {
    "request_id": "req-123",
    "trace_id": "tr-456"
  }
}
```

### Response Format (Error)

```json
{
  "ok": false,
  "error": {
    "code": "routing_failed",
    "message": "Task type indicates failure",
    "details": {
      "tenant_id": "acme"
    }
  },
  "context": {
    "request_id": "req-123",
    "trace_id": "tr-456"
  }
}
```

---

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_MOCK_ROUTER` | `false` | Enable Mock Router in test_helper.exs |
| `NATS_URL` | `nats://localhost:4222` | NATS server URL |

### Example: Running Tests with Mock Router

```bash
# Enable Mock Router and set NATS URL
ENABLE_MOCK_ROUTER=true NATS_URL=nats://localhost:4222 mix test

# Or in CI/CD
ENABLE_MOCK_ROUTER=true NATS_URL=nats://nats:4222 mix test
```

---

## 🧪 Testing with Mock Router

### E2E Test Example

```elixir
defmodule UiWeb.E2E.RouterIntegrationTest do
  use ExUnit.Case, async: false
  
  setup do
    # Start Mock Router
    {:ok, _pid} = UiWeb.Test.MockRouter.start()
    
    on_exit(fn ->
      UiWeb.Test.MockRouter.stop()
    end)
    
    :ok
  end
  
  test "end-to-end routing flow" do
    # Your E2E test that uses Router via NATS
    # Mock Router will respond with predictable decisions
  end
end
```

### Playwright E2E Test

```javascript
// In Playwright E2E tests, Mock Router is started automatically
// if ENABLE_MOCK_ROUTER=true is set in the environment

test('routing flow works end-to-end', async ({ page }) => {
  // Navigate to page that triggers Router request
  await page.goto('/app/messages');
  
  // Mock Router will respond to NATS requests
  // with predictable RouteDecision
});
```

---

## 📊 Implementation Details

### Module: `UiWeb.Test.MockRouter`

**GenServer-based:**
- Maintains NATS connection via `Gnat`
- Subscribes to `beamline.router.v1.decide`
- Responds to requests with generated RouteDecision

**Error Handling:**
- Gracefully handles NATS connection failures (logs warning, doesn't crash)
- Validates request JSON before processing
- Returns error responses for invalid requests

**State Management:**
- Tracks NATS connection and subscription
- Handles connection lifecycle (start, stop, reconnect)

---

## 🔍 Debugging

### Enable Debug Logging

```elixir
# In config/test.exs
config :logger, level: :debug
```

### Check Mock Router Status

```elixir
# In IEx
iex> UiWeb.Test.MockRouter.running?()
true

iex> Process.whereis(UiWeb.Test.MockRouter)
#PID<0.123.0>
```

### Monitor NATS Messages

```elixir
# In IEx, subscribe to NATS subject manually
{:ok, conn} = Gnat.start_link(name: :debug_gnat)
{:ok, sub} = Gnat.sub(conn, self(), "beamline.router.v1.decide")

# Monitor messages
receive do
  {:msg, %{topic: topic, body: body}} ->
    IO.inspect({topic, body})
end
```

---

## 📚 Files

### Core Implementation

- **`apps/ui_web/lib/ui_web/test/mock_router.ex`** - Mock Router GenServer
- **`apps/ui_web/test/test_helper.exs`** - Auto-start configuration

### Dependencies

- **`gnat`** - NATS client library (already in mix.exs)

---

## ✅ Acceptance Criteria

1. ✅ Mock Router subscribes to `beamline.router.v1.decide`
2. ✅ Generates predictable RouteDecision responses
3. ✅ Handles special cases (slow_tenant, expensive_tenant, etc.)
4. ✅ Returns error responses for invalid requests
5. ✅ Gracefully handles NATS connection failures
6. ✅ Can be started/stopped manually or automatically
7. ✅ Documentation complete

---

## 🚀 Next Steps (Optional)

### Enhanced Features

1. **Configurable Decision Rules:**
   - Allow test-specific decision rules via configuration
   - Support for custom provider selection logic

2. **Request/Response Logging:**
   - Log all requests and responses for debugging
   - Export logs as artifacts in CI/CD

3. **Performance Metrics:**
   - Track response times
   - Monitor NATS message throughput

4. **Multi-Tenant Support:**
   - Support for multiple tenant-specific rules
   - Tenant-specific provider preferences

---

## 📖 References

- **NATS Subjects:** `docs/NATS_SUBJECTS.md`
- **Router Protocol:** `docs/ARCHITECTURE/PROTO_NATS_MAPPING.md`
- **CP1 Boundaries:** `docs/archive/dev/CP1_BOUNDARIES_AND_CONTRACTS.md`
- **Gnat Library:** https://hex.pm/packages/gnat

