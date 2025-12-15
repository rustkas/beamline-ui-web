# 🚀 Quick Start: Integration Testing

**One-page reference for running integration tests**

---

## ⚡ Quick Commands

### Run All Tests
```bash
cd apps/ui_web

# Unit tests only (fast)
mix test --exclude integration --exclude e2e

# Integration tests (requires Gateway)
mix test --include integration

# End-to-end tests (full flow)
mix test --include e2e

# Everything
mix test --include integration --include e2e
```

### Use Test Runner Script
```bash
# Full suite with cleanup and reporting
elixir scripts/run_integration_tests.exs \
  --all --cleanup --save-report

# Just integration tests
elixir scripts/run_integration_tests.exs --integration

# Stress testing
elixir scripts/run_integration_tests.exs --e2e --stress
```

---

## 🔧 Gateway Setup

### Start Gateway Manually
```bash
cd apps/c-gateway

# Build if needed
cmake -B build && cmake --build build

# Start Gateway
GATEWAY_PORT=8080 ./build/c-gateway &
GATEWAY_PID=$!

# Check health
curl http://localhost:8080/_health

# Stop when done
kill $GATEWAY_PID
```

### Verify Gateway is Running
```bash
# Check process
ps aux | grep c-gateway

# Check port
lsof -i :8080

# Test health endpoint
curl -s http://localhost:8080/_health | jq .
```

---

## 📊 Test Categories

| Tag | Command | Description |
|-----|---------|-------------|
| (none) | `mix test` | Unit tests only |
| `:integration` | `mix test --include integration` | Gateway API tests |
| `:e2e` | `mix test --include e2e` | Complete flows |
| Both | `mix test --include integration --include e2e` | All integration |

---

## 🐛 Troubleshooting

### Gateway Connection Refused
```bash
# Check if Gateway is running
ps aux | grep c-gateway

# Start Gateway
cd apps/c-gateway && GATEWAY_PORT=8080 ./build/c-gateway &
```

### Test Failures
```bash
# Run specific test file
mix test test/ui_web/integration/gateway_integration_test.exs

# Run with trace for details
mix test --include integration --trace

# Run previously failed tests
mix test --failed
```

### Clean Test Data
```elixir
# In IEx
iex -S mix
UiWeb.TestDataManager.cleanup_all_test_data()
UiWeb.TestDataManager.get_cleanup_stats()
```

---

## 📝 Example Test Run

```bash
# 1. Ensure Gateway is running
curl http://localhost:8080/_health || echo "Gateway not running!"

# 2. Run integration tests
cd apps/ui_web
mix test --include integration --trace

# Expected output:
# .........................
# 
# Finished in X.X seconds
# 25 tests, 0 failures
```

---

## 📚 Documentation

- **Full Guide**: [INTEGRATION_TESTING.md](docs/INTEGRATION_TESTING.md)
- **Validation Checklist**: [INTEGRATION_TESTING_VALIDATION.md](docs/INTEGRATION_TESTING_VALIDATION.md)
- **Implementation Summary**: [INTEGRATION_TESTING_COMPLETE.md](INTEGRATION_TESTING_COMPLETE.md)

---

## ✅ Pre-Commit Checklist

Before committing code that touches integration:

- [ ] Run unit tests: `mix test --exclude integration --exclude e2e`
- [ ] Run integration tests: `mix test --include integration`
- [ ] Cleanup test data verified: No orphaned test messages
- [ ] Documentation updated if API changed
- [ ] New tests added for new features

---

**Quick Help**: For detailed troubleshooting and advanced usage, see [INTEGRATION_TESTING.md](docs/INTEGRATION_TESTING.md)
