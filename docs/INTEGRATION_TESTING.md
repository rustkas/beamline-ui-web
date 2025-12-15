# Integration Testing Guide

## Related Documentation

- **[UI_WEB_GATEWAY_INTEGRATION.md](./UI_WEB_GATEWAY_INTEGRATION.md)** - GatewayClient and Mock Gateway usage
- **[UI_WEB_REALTIME.md](./UI_WEB_REALTIME.md)** - Real-time testing strategies
- **[UI_WEB_TEST_STRATEGY.md](./UI_WEB_TEST_STRATEGY.md)** - Testing strategy for LiveView, mocks, and helpers

This guide provides comprehensive information about the integration testing infrastructure for UI-Web ↔ Gateway communication.

## 🚀 Quick Start

### Run Integration Tests

```bash
# Run all integration tests
cd apps/ui_web
mix test --include integration

# Run only end-to-end tests
mix test --include e2e

# Run specific test file
mix test test/ui_web/integration/gateway_integration_test.exs

# Run with trace output
mix test --include integration --trace
```

### Use Test Runner Script

```bash
# Run comprehensive integration test suite
cd apps/ui_web
elixir scripts/run_integration_tests.exs --integration --cleanup --save-report

# Run only unit tests
elixir scripts/run_integration_tests.exs --unit

# Run stress tests
elixir scripts/run_integration_tests.exs --e2e --stress
```

## 🏗️ Architecture

### Test Categories

1. **Unit Tests** (`--unit`)
   - Test individual components in isolation
   - Fast execution (< 1 second per test)
   - No external dependencies

2. **Integration Tests** (`--integration`)
   - Test UI-Web ↔ Gateway communication
   - Real HTTP requests to Gateway
   - Test API contracts and error handling

3. **End-to-End Tests** (`--e2e`)
   - Complete message flow testing
   - SSE event verification
   - Multi-tenant isolation tests

4. **Stress Tests** (`--stress`)
   - Performance under load
   - Concurrent operation testing
   - Resource usage monitoring

### Test Data Management

The `TestDataManager` provides:
- Automatic test data creation
- Cleanup after tests
- Data isolation between test runs
- Audit trail for debugging

## 🔧 Configuration

### Environment Variables

```bash
# Gateway configuration
export GATEWAY_URL=http://localhost:8080
export GATEWAY_TIMEOUT=5000
export GATEWAY_RETRY_ATTEMPTS=3

# Test configuration
export TEST_TENANT_ID=integration_test
export TEST_LOG_LEVEL=info

# Performance settings
export PERF_CONCURRENT_REQUESTS=10
export PERF_TOTAL_REQUESTS=100

# CI/CD settings
export CI=true
export CLEANUP_AFTER_TESTS=true
```

### Test Configuration Files

- `config/test_integration.exs` - Integration test settings
- `test/support/integration_test_helper.ex` - Helper functions
- `test/support/test_data_manager.ex` - Data management

## 📋 Test Coverage

### Gateway Integration Tests

- ✅ Health endpoint connectivity
- ✅ Metrics endpoint parsing
- ✅ Message CRUD operations
- ✅ SSE streaming functionality
- ✅ Error handling scenarios
- ✅ Rate limiting behavior
- ✅ Multi-tenant isolation
- ✅ Concurrent operation handling

### End-to-End Tests

- ✅ Complete message flow (Create → Gateway → SSE → UI)
- ✅ Event propagation verification
- ✅ Multi-tenant event isolation
- ✅ Error recovery and resilience
- ✅ Performance under load
- ✅ Edge case handling

## 🧪 Test Examples

### Basic Integration Test

```elixir
defmodule MyIntegrationTest do
  use ExUnit.Case, async: false
  alias UiWeb.Services.GatewayClient
  
  @moduletag :integration
  
  test "gateway health check" do
    assert {:ok, health} = GatewayClient.fetch_health()
    assert health["status"] == "ok"
  end
end
```

### End-to-End Test with Events

```elixir
defmodule MyEndToEndTest do
  use ExUnit.Case, async: false
  alias Phoenix.PubSub
  
  @moduletag :e2e
  @moduletag :integration
  
  setup do
    PubSub.subscribe(UiWeb.PubSub, "messages:test_tenant")
    :ok
  end
  
  test "message creation triggers sse event" do
    message_data = %{"content" => "test", "type" => "test"}
    
    # Create message
    assert {:ok, response} = GatewayClient.post_json("/api/v1/messages", message_data)
    
    # Wait for SSE event
    assert_receive {:message_created, event}, 2_000
    assert event["content"] == message_data["content"]
  end
end
```

### Using Test Helpers

```elixir
defmodule MyTest do
  use ExUnit.Case
  alias UiWeb.IntegrationTestHelper
  
  test "with helper functions" do
    # Create test data
    message = IntegrationTestHelper.create_test_message(%{
      "content" => "My test message"
    })
    
    # Measure operation performance
    {result, time_ms} = IntegrationTestHelper.measure_gateway_operation(
      :create_message, 
      message
    )
    
    assert elem(result, 0) == :ok
    assert time_ms < 1000 # Should complete within 1 second
  end
end
```

## 🔍 Debugging

### Enable Verbose Logging

```bash
export TEST_LOG_LEVEL=debug
export GATEWAY_DEBUG=true
```

### Check Gateway Logs

```bash
# Gateway logs are usually in stderr
tail -f apps/c-gateway/gateway.log

# Or check the process directly
ps aux | grep gateway
```

### Test Data Inspection

```elixir
# Check test data manager state
{:ok, stats} = UiWeb.TestDataManager.get_cleanup_stats()
IO.inspect(stats)

# Validate integration config
UiWeb.IntegrationTestHelper.print_integration_config()
```

## 🚨 Troubleshooting

### Common Issues

1. **Gateway Connection Refused**
   ```
   Error: connection refused to localhost:8080
   ```
   **Solution**: Start Gateway service first:
   ```bash
   cd apps/c-gateway
   GATEWAY_PORT=8080 ./build/c-gateway
   ```

2. **Test Timeouts**
   ```
   ** (ExUnit.TimeoutError) test timed out after 60000ms
   ```
   **Solution**: Increase timeout in test or check Gateway performance:
   ```elixir
   @tag timeout: 120_000 # 2 minutes
   ```

3. **SSE Events Not Received**
   ```
   Expected to receive message but got nothing
   ```
   **Solution**: Check SSE bridge is running and subscribed to correct tenant:
   ```elixir
   Phoenix.PubSub.subscribe(UiWeb.PubSub, "messages:your_tenant")
   ```

4. **Rate Limiting**
   ```
   Error: 429 Too Many Requests
   ```
   **Solution**: Add delays between requests or disable rate limiting:
   ```elixir
   Process.sleep(1000) # Wait 1 second between requests
   ```

### Performance Issues

- **Slow Tests**: Run tests concurrently where possible
- **Gateway Overload**: Reduce concurrent test count
- **Memory Usage**: Enable test data cleanup

## 📊 Performance Benchmarking

### Run Performance Tests

```bash
# Run performance benchmark
cd apps/ui_web
elixir scripts/performance_benchmark.exs

# Run stress test
elixir scripts/stress_test.exs --concurrent 50 --requests 1000
```

### Performance Metrics

- **Response Time**: < 100ms for simple operations
- **Throughput**: > 1000 requests/second
- **Memory Usage**: < 100MB per test suite
- **CPU Usage**: < 50% during stress tests

## 🔄 CI/CD Integration

### GitHub Actions

The integration tests run automatically on:
- Pull requests to main/develop
- Pushes to main/develop
- Manual workflow dispatch

### Test Results

Test results are available as:
- GitHub Actions artifacts
- PR comments with summaries
- Detailed JSON reports

### Deployment Gates

Integration tests must pass before:
- Merging to main branch
- Production deployment
- Release creation

## 📚 Additional Resources

### Related Documentation

- [Gateway API Specification](../c-gateway/docs/API_SPEC.md)
- [UI-Web Architecture](ARCHITECTURE.md)
- [Testing Best Practices](TESTING_BEST_PRACTICES.md)

### Useful Commands

```bash
# Check test coverage
mix coveralls.html

# Generate test documentation
mix docs

# Run tests continuously
mix test.watch

# Profile test performance
mix profile.fprof -e "ExUnit.run()"
```

## 🤝 Contributing

### Adding New Integration Tests

1. Create test file in `test/ui_web/integration/`
2. Add appropriate `@moduletag` (:integration or :e2e)
3. Use TestDataManager for data creation/cleanup
4. Add performance assertions where relevant
5. Update this documentation

### Improving Test Performance

1. Use `async: true` where possible
2. Batch operations with bulk helpers
3. Minimize external dependencies
4. Use appropriate timeouts
5. Profile slow tests

### Reporting Issues

When reporting integration test issues:
1. Include test output and logs
2. Specify environment (local, CI, etc.)
3. Include Gateway version and configuration
4. Provide steps to reproduce
5. Attach test reports if available