# UI-Web Gateway Integration Guide

## Overview

UI-Web communicates with the C-Gateway service via HTTP to access backend functionality (messages, extensions, policies). All HTTP communication goes through the `GatewayClient` module, which provides:

- **Unified HTTP client** with retry logic and error handling
- **Health monitoring** with circuit breaker pattern
- **Mock fallback** for local development and testing
- **Telemetry** for observability

**Why GatewayClient?** Instead of making direct HTTP calls from LiveViews or other modules, all requests go through `GatewayClient`, ensuring consistent error handling, retry logic, and observability across the application.

## Architecture

```
┌─────────────────┐
│   LiveView      │
│ (ExtensionsLive │
│  MessagesLive)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Service Client │
│ (MessagesClient │
│ ExtensionsClient)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  GatewayClient  │
│  (HTTP + Retry)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   C-Gateway     │
│   (Port 8080)   │
└─────────────────┘
```

### File Structure

- **`lib/ui_web/services/gateway_client.ex`** - Core HTTP client with retry, health checks, and circuit breaker
- **`lib/ui_web/services/messages_client.ex`** - Messages API client
- **`lib/ui_web/services/extensions_client.ex`** - Extensions Registry API client
- **`lib/ui_web_web/gateway_error_helper.ex`** - Error formatting helper for UI

## GatewayClient: Responsibilities

### What GatewayClient Does

1. **Base HTTP Client (Req)**
   - Wraps `Req` library for HTTP requests
   - Handles JSON encoding/decoding
   - Manages request timeouts

2. **Automatic Retry with Exponential Backoff**
   - Retries transient failures (network errors, 5xx responses)
   - Exponential backoff: `2^attempt` seconds
   - Configurable retry attempts (default: 3)

3. **Health Check Monitoring**
   - Periodic health checks every 30 seconds (configurable)
   - Circuit breaker: marks Gateway as unhealthy after 3 consecutive failures
   - Response caching: health check results cached for 5 seconds to prevent DDoS
   - Request deduplication: concurrent health checks are combined into one

4. **Mock Fallback**
   - Automatically falls back to Mock Gateway when `USE_MOCK_GATEWAY=true`
   - Mock Gateway runs on port 8081 (for tests) or uses test server
   - Seamless switching between real and mock Gateway

5. **Telemetry**
   - Emits `[:ui_web, :gateway, :request]` events with:
     - `duration` (nanoseconds)
     - `method`, `path`, `base_url`
     - `result` (`:ok`, `:client_error`, `:server_error`, `:timeout`, `:error`)
   - Emits `[:ui_web, :gateway, :health_check]` events with:
     - `duration` (nanoseconds)
     - `result` (`:ok`, `:timeout`, `:error`, `:cache_hit`)

### What GatewayClient Does NOT Do

- ❌ **No business logic** - GatewayClient is a pure HTTP client
- ❌ **No error formatting for UI** - Use `GatewayErrorHelper.format_gateway_error/1` instead
- ❌ **No data transformation** - Returns raw API responses

## Unified Error Contract

All GatewayClient methods return a consistent result format:

### Success
```elixir
{:ok, body}  # body is decoded JSON (map/list)
```

### HTTP Errors
```elixir
{:error, {:http_error, status, body}}
# Examples:
# {:error, {:http_error, 404, %{"error" => "Not found"}}}
# {:error, {:http_error, 500, %{"error" => "Internal server error"}}}
```

### Network Errors
```elixir
{:error, :timeout}           # Request timeout
{:error, :nxdomain}          # DNS resolution failed
{:error, :econnrefused}      # Connection refused
{:error, :enotfound}         # Host not found
{:error, other}              # Other network errors
```

### Error Formatting

**Always use `GatewayErrorHelper.format_gateway_error/1`** to format errors for UI:

```elixir
case MessagesClient.list_messages() do
  {:ok, data} ->
    # Handle success
    assign(socket, :messages, data["data"])

  {:error, reason} ->
    # Format error for user
    msg = GatewayErrorHelper.format_gateway_error(reason)
    put_flash(socket, :error, "Failed to load messages. " <> msg)
end
```

See `lib/ui_web_web/gateway_error_helper.ex` for all supported error formats.

## Configuration

### Environment Variables

**Gateway Configuration:**
- `GATEWAY_URL` - Gateway base URL (default: `http://localhost:8080`)
- `GATEWAY_TIMEOUT_MS` - Request timeout in milliseconds (default: `10000`)
- `GATEWAY_RETRY_ATTEMPTS` - Number of retry attempts (default: `3`)
- `GATEWAY_HEALTH_CHECK_MS` - Health check interval in milliseconds (default: `30000`)

**Feature Flags:**
- `USE_MOCK_GATEWAY` - Use Mock Gateway instead of real one (default: `false`)
  - Set to `"true"` for local development without C-Gateway
  - Automatically enabled in test environment

**Example `.env.local`:**
```bash
GATEWAY_URL=http://localhost:8080
GATEWAY_TIMEOUT_MS=10000
GATEWAY_RETRY_ATTEMPTS=3
USE_MOCK_GATEWAY=false
```

### Configuration Files

- **`config/runtime.exs`** - Runtime configuration (reads from environment variables)
- **`config/dev.exs`** - Development overrides
- **`config/test.exs`** - Test configuration (uses Mock Gateway by default)
- **`config/prod.exs`** - Production configuration (requires `GATEWAY_URL` and `NATS_URL`)

## Client Layer (MessagesClient, ExtensionsClient)

### Pattern

Service clients in `UiWeb.Services.*` namespace:

- **Do NOT know about LiveView** - They are pure API clients
- **Map API endpoints to functions**:
  - `list_*` - List resources with filters/pagination
  - `get_*` - Get single resource by ID
  - `create_*` - Create new resource
  - `update_*` - Update existing resource
  - `delete_*` - Delete resource
  - Bulk operations: `bulk_delete_*`, `export_*`

### Example: MessagesClient

```elixir
defmodule UiWeb.Services.MessagesClient do
  alias UiWeb.Services.GatewayClient

  def list_messages(opts \\ []) do
    params = build_query_params(opts)
    GatewayClient.get_json("/api/v1/messages", params: params)
  end

  def get_message(message_id) do
    GatewayClient.get_json("/api/v1/messages/#{message_id}")
  end

  def create_message(message_data) do
    GatewayClient.post_json("/api/v1/messages", message_data)
  end

  # ... other methods
end
```

### Creating a New Client

**Steps to create `FooClient`:**

1. **Create module** in `lib/ui_web/services/foo_client.ex`:
   ```elixir
   defmodule UiWeb.Services.FooClient do
     alias UiWeb.Services.GatewayClient

     def list_foos(opts \\ []) do
       params = build_query_params(opts)
       GatewayClient.get_json("/api/v1/foos", params: params)
     end

     def get_foo(id) do
       GatewayClient.get_json("/api/v1/foos/#{id}")
     end

     # ... other methods
   end
   ```

2. **Use GatewayClient methods:**
   - `GatewayClient.get_json(path, opts)` - GET request
   - `GatewayClient.post_json(path, body, opts)` - POST request
   - `GatewayClient.put_json(path, body, opts)` - PUT request
   - `GatewayClient.patch_json(path, body, opts)` - PATCH request
   - `GatewayClient.delete_json(path, opts)` - DELETE request
   - `GatewayClient.request(method, path, body, opts)` - Generic request

3. **Handle query parameters:**
   ```elixir
   defp build_query_params(opts) do
     opts
     |> Enum.filter(fn {_k, v} -> v != nil end)
     |> Enum.into(%{})
   end
   ```

## Usage Examples

### In LiveView

```elixir
defmodule UiWebWeb.MessagesLive.Index do
  alias UiWeb.Services.MessagesClient
  alias UiWebWeb.GatewayErrorHelper

  def load_messages(socket) do
    opts = [
      status: socket.assigns.filter_status,
      type: socket.assigns.filter_type,
      limit: 50,
      offset: socket.assigns.pagination["offset"]
    ]

    case MessagesClient.list_messages(opts) do
      {:ok, %{"data" => messages, "pagination" => pagination}} ->
        socket
        |> assign(:loading, false)
        |> assign(:messages, messages)
        |> assign(:pagination, pagination)

      {:error, reason} ->
        msg = GatewayErrorHelper.format_gateway_error(reason)
        socket
        |> assign(:loading, false)
        |> assign(:messages, [])
        |> put_flash(:error, "Failed to load messages. " <> msg)
    end
  end
end
```

### Error Handling Pattern

```elixir
case ExtensionsClient.toggle_extension(id, enabled) do
  {:ok, updated} ->
    # Success - update UI
    socket
    |> put_flash(:info, "Extension updated")
    |> load_extensions()

  {:error, {:http_error, 404, _}} ->
    # Resource not found
    put_flash(socket, :error, "Extension not found")

  {:error, reason} ->
    # Generic error - use helper
    msg = GatewayErrorHelper.format_gateway_error(reason)
    put_flash(socket, :error, "Failed to update extension. " <> msg)
end
```

## Testing & Mocks

### Mock Gateway

**File:** `test/support/mock_gateway.ex`

Mock Gateway is a Plug.Router-based server that:

- Runs on port **8081** (for tests)
- Implements all Gateway endpoints:
  - `GET /_health` - Health check
  - `GET /metrics` - Metrics endpoint
  - `GET /api/v1/messages` - List messages
  - `POST /api/v1/messages` - Create message
  - `GET /api/v1/messages/:id` - Get message
  - `PUT /api/v1/messages/:id` - Update message
  - `DELETE /api/v1/messages/:id` - Delete message
  - `POST /api/v1/messages/bulk_delete` - Bulk delete
  - `POST /api/v1/messages/export` - Export messages
  - Similar endpoints for extensions

**How it works:**
- Automatically started in `test_helper.exs`
- `USE_MOCK_GATEWAY=true` in test environment
- `GatewayClient` automatically routes to Mock Gateway when flag is set

### Writing Contract Tests

**Example:**
```elixir
defmodule UiWeb.Services.MessagesClientTest do
  use ExUnit.Case

  alias UiWeb.Services.MessagesClient

  test "list_messages returns paginated results" do
    assert {:ok, %{"data" => messages, "pagination" => pagination}} =
           MessagesClient.list_messages(limit: 10, offset: 0)

    assert is_list(messages)
    assert is_map(pagination)
    assert Map.has_key?(pagination, "total")
  end
end
```

**See also:**
- `docs/INTEGRATION_TESTING.md` - Integration testing guide
- `docs/INTEGRATION_TESTING_VALIDATION.md` - Contract validation

## Known Pitfalls / Best Practices

### ❌ Don't Bypass GatewayClient

**Bad:**
```elixir
# Direct Req call - bypasses retry, health checks, telemetry
Req.get!("http://localhost:8080/api/v1/messages")
```

**Good:**
```elixir
# Use GatewayClient
MessagesClient.list_messages()
```

### ✅ Always Use Error Helper

**Bad:**
```elixir
{:error, reason} ->
  put_flash(socket, :error, "Error: #{inspect(reason)}")  # Technical details leak
```

**Good:**
```elixir
{:error, reason} ->
  msg = GatewayErrorHelper.format_gateway_error(reason)
  put_flash(socket, :error, "Failed to load. " <> msg)
```

### ✅ Don't Hardcode URLs

**Bad:**
```elixir
url = "http://localhost:8080/api/v1/messages"  # Hardcoded
```

**Good:**
```elixir
GatewayClient.get_json("/api/v1/messages")  # Uses configured base URL
```

### ✅ Handle All Error Cases

```elixir
case MessagesClient.get_message(id) do
  {:ok, message} ->
    # Success

  {:error, {:http_error, 404, _}} ->
    # Not found - specific handling

  {:error, :timeout} ->
    # Timeout - specific handling

  {:error, reason} ->
    # Generic error - use helper
    msg = GatewayErrorHelper.format_gateway_error(reason)
    # ...
end
```

## Related Documentation

- **`docs/UI_WEB_REALTIME.md`** - Real-time updates via NATS
- **`docs/UI_WEB_TEST_STRATEGY.md`** - Testing strategy for LiveView, mocks, and helpers
- **`docs/API_CONTRACTS.md`** - API contract specifications
- **`docs/INTEGRATION_TESTING.md`** - Integration testing guide
- **`lib/ui_web/services/gateway_client.ex`** - GatewayClient source code
- **`lib/ui_web_web/gateway_error_helper.ex`** - Error formatting helper

