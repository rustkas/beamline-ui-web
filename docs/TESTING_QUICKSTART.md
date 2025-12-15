# UI Web Testing Quick Start

**Quick reference guide for writing and running tests in `ui_web`.**

For comprehensive details, see [UI_WEB_TEST_STRATEGY.md](./UI_WEB_TEST_STRATEGY.md).

---

## 🚀 Running Tests

### All Tests
```bash
mix test
```

### LiveView Tests Only
```bash
mix test --include live_view
```

### Specific Test File
```bash
mix test test/ui_web_web/live/messages_live/index_test.exs
```

### With Trace (for debugging)
```bash
mix test --trace
```

---

## 🎯 Writing a New LiveView Test

### Step 1: Create Test File

```elixir
defmodule UiWebWeb.YourLive.IndexTest do
  use UiWebWeb.LiveViewCase

  @moduletag :live_view
  @moduletag :integration

  test "renders resource list on load", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/app/your_resource")
    assert_html(view, "Expected Text", timeout: 1000)
  end
end
```

### Step 2: Add Mock Endpoints

In `test/support/mock_gateway.ex`:

```elixir
get "/api/v1/your_resource" do
  query = conn.query_params
  
  case Map.get(query, "status") do
    "force_error" ->
      json_response(conn, 500, %{"error" => "forced_error"})
    _ ->
      mock_data = generate_mock_data()
      json_response(conn, 200, %{
        data: mock_data,
        pagination: %{total: length(mock_data), limit: 20, offset: 0}
      })
  end
end
```

**Important**: Always use `json_response/3` for JSON responses.

### Step 3: Use Test Helpers

```elixir
# Wait for text to appear
assert_html(view, "Expected Text", timeout: 1000)

# Wait for text to disappear
refute_html(view, "Old Text", timeout: 1000)

# Check element exists
assert_element(view, "table")

# Retry complex assertions
eventually(fn ->
  assert something_complex()
end)
```

**Never use `Process.sleep`** - use `assert_html`/`eventually` instead.

### Step 4: Test Key Scenarios

```elixir
# Happy path
test "renders resource list", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/resources")
  assert_html(view, "Resource 1", timeout: 1000)
end

# Filtering
test "filters by status", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/resources")
  view |> form("#filters", %{status: "active"}) |> render_change()
  assert_html(view, "Active Resource", timeout: 1000)
  refute_html(view, "Inactive Resource", timeout: 1000)
end

# Actions
test "deletes resource", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/resources")
  view
  |> element("button[phx-click='delete'][phx-value-id='res_001']")
  |> render_click()
  refute_html(view, "res_001", timeout: 2000)
end

# Error handling
test "shows error when load fails", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/resources?status=force_error")
  assert_html(view, ~r/Failed to load|error/i, timeout: 2000)
end
```

---

## 🔧 Creating a New API Client

### Step 1: Create Client Module

```elixir
defmodule UiWeb.Services.YourResourceClient do
  @moduledoc """
  HTTP client for YourResource API.
  """

  alias UiWeb.Services.GatewayClient
  alias UiWeb.Services.ClientHelpers

  @spec list_resources(keyword()) :: {:ok, map()} | {:error, term()}
  def list_resources(opts \\ []) do
    query_params = ClientHelpers.build_query_params(opts)
    GatewayClient.get_json("/api/v1/your_resource", params: query_params)
  end

  @spec get_resource(String.t()) :: {:ok, map()} | {:error, term()}
  def get_resource(id) do
    GatewayClient.get_json("/api/v1/your_resource/#{id}")
  end

  @spec create_resource(map()) :: {:ok, map()} | {:error, term()}
  def create_resource(attrs) do
    GatewayClient.post_json("/api/v1/your_resource", attrs)
  end

  @spec update_resource(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def update_resource(id, attrs) do
    GatewayClient.put_json("/api/v1/your_resource/#{id}", attrs)
  end

  @spec delete_resource(String.t()) :: :ok | {:error, term()}
  def delete_resource(id) do
    GatewayClient.delete("/api/v1/your_resource/#{id}")
  end
end
```

### Step 2: Key Patterns

**Always use `ClientHelpers.build_query_params/1`**:
```elixir
query_params = ClientHelpers.build_query_params(opts)
GatewayClient.get_json("/api/v1/resource", params: query_params)
```

**Use convenience methods**:
- `GatewayClient.get_json(path, opts)` for GET
- `GatewayClient.post_json(path, body, opts)` for POST
- `GatewayClient.put_json(path, body, opts)` for PUT
- `GatewayClient.delete(path, opts)` for DELETE

**Response format**:
- Success: `{:ok, data}` (map, list, or binary)
- Error: `{:error, reason}` (normalized by `ClientHelpers`)

---

## 🛠️ ClientHelpers Overview

**Location**: `lib/ui_web/services/client_helpers.ex`

### Key Functions

**`build_query_params/1`** - Filter nil/empty values:
```elixir
ClientHelpers.build_query_params([status: "active", type: nil, search: ""])
# => %{status: "active"}
```

**`normalize_response/1`** - Normalize Gateway responses:
```elixir
# Automatically called by GatewayClient
# Converts {:ok, %{"error" => _}} to error tuple
# Handles 204 No Content, empty bodies, JSON strings
```

**`handle_delete_response/1`** - Convert delete success to `:ok`:
```elixir
ClientHelpers.handle_delete_response({:ok, _})  # => :ok
ClientHelpers.handle_delete_response({:error, reason})  # => {:error, reason}
```

**`extract_items/1`** - Extract items from paginated responses:
```elixir
ClientHelpers.extract_items(%{"data" => items})  # => items
ClientHelpers.extract_items(%{"items" => items})  # => items
```

---

## 🎭 Mock Gateway

### Location
`test/support/mock_gateway.ex`

### Running
Mock Gateway starts automatically on port `8081` during tests.

### Adding Endpoints

```elixir
get "/api/v1/your_resource" do
  query = conn.query_params
  
  # Error simulation
  case Map.get(query, "status") do
    "force_error" ->
      json_response(conn, 500, %{"error" => "forced_error"})
    _ ->
      # Success response
      json_response(conn, 200, %{data: mock_data})
  end
end
```

### Important Rules

1. **Always use `json_response/3`** for JSON responses
2. **Support `force_error`** for error testing
3. **Use ETS** for state management (shared across processes)
4. **Reset state** in test `setup` if needed

### Helper Function

```elixir
defp json_response(conn, status, body) do
  conn
  |> put_resp_content_type("application/json")
  |> send_resp(status, Jason.encode!(body))
end
```

---

## 📋 Test Checklist

When writing a new LiveView test:

- [ ] Test file uses `UiWebWeb.LiveViewCase`
- [ ] Has `@moduletag :live_view` and `@moduletag :integration`
- [ ] Mock endpoints added to `mock_gateway.ex`
- [ ] All responses use `json_response/3`
- [ ] No `Process.sleep` calls
- [ ] Uses `assert_html`/`refute_html`/`eventually` for async operations
- [ ] Tests happy path, filtering, pagination, actions, errors
- [ ] Tests error flows (`force_error`, specific error IDs)

---

## 🔗 Key References

- **[UI_WEB_TEST_STRATEGY.md](./UI_WEB_TEST_STRATEGY.md)** - Complete testing strategy
- **[CONTRACT_TESTING.md](./CONTRACT_TESTING.md)** - Mock Gateway as API specification
- **[UI_WEB_GATEWAY_INTEGRATION.md](./UI_WEB_GATEWAY_INTEGRATION.md)** - Gateway integration details
- **[UI_WEB_REALTIME.md](./UI_WEB_REALTIME.md)** - Real-time updates via NATS

### Golden Examples

- `MessagesLive.Index` - Full CRUD, filtering, pagination, bulk operations
- `ExtensionsLive.Index` - CRUD, toggle, filtering, pagination
- `PoliciesLive` - CRUD, JSON validation, polling
- `DashboardLive` - Polling, metrics, health, error handling

### Test Files

- `test/ui_web_web/live/messages_live/index_test.exs`
- `test/ui_web_web/live/extensions_live/index_test.exs`
- `test/ui_web/services/client_helpers_test.exs`

---

## 🆘 Common Issues

### Test Times Out

**Problem**: `assert_html` times out

**Solution**: 
- Increase timeout: `assert_html(view, "text", timeout: 3000)`
- Check mock gateway is running
- Verify mock endpoint returns correct data

### Mock Gateway Not Responding

**Problem**: Tests fail with connection errors

**Solution**:
- Check Mock Gateway starts automatically
- Verify port `8081` is available
- Check `test/support/mock_gateway_server.ex` is configured

### Tests Are Flaky

**Problem**: Tests pass/fail randomly

**Solution**:
- Remove all `Process.sleep` calls
- Use `assert_html`/`eventually` instead
- Ensure tests are independent (reset state in `setup`)

---

## 💡 Tips

1. **Start with Golden Examples** - Copy patterns from `MessagesLive.Index` or `ExtensionsLive.Index`
2. **Test Incrementally** - Write one test, run it, fix it, then add more
3. **Use `--trace`** - When debugging, use `mix test --trace` for detailed output
4. **Check Mock Data** - Verify mock endpoints return expected data format
5. **Read Test Strategy** - For complex scenarios, refer to full documentation

---

*Last updated: 2025-01-27*
*For questions or improvements, see [UI_WEB_TEST_STRATEGY.md](./UI_WEB_TEST_STRATEGY.md)*

