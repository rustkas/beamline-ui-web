# UI Web Test Strategy

## Purpose

This document defines the unified testing strategy for LiveView, Gateway mocks, and client layer in `ui_web`. It establishes patterns, conventions, and best practices based on proven implementations in four golden examples: `MessagesLive.Index`, `ExtensionsLive.Index`, `PoliciesLive`, and `DashboardLive`.

**Quick Start**: For a fast reference guide, see [TESTING_QUICKSTART.md](./TESTING_QUICKSTART.md).

---

## 1. Testing Architecture

### 1.1 Test Levels

**Unit Tests**
- Test individual functions in isolation (clients, utils, helpers)
- Example: `ExtensionsClient.list_extensions/1`, `GatewayErrorHelper.format_gateway_error/1`

**Integration Tests (LiveView)**
- Test full flow: LiveView ←→ Client ←→ Mock Gateway
- Use `@moduletag :live_view` and `@moduletag :integration`
- Example: `MessagesLive.IndexTest`, `ExtensionsLive.IndexTest`

**Contract Tests**
- Verify mock endpoints match real Gateway API contracts
- Ensure request/response formats are consistent
- Validate error handling matches production behavior

### 1.2 Test Infrastructure

**`LiveViewCase`** (`test/support/live_view_case.ex`)
- Base test case for all LiveView tests
- Provides authenticated connection via Guardian
- Imports `UiWeb.TestHelpers` automatically
- Waits for Mock Gateway to be ready
- Sets up test user and session

**`UiWeb.TestHelpers`** (`test/support/test_helpers.ex`)
- Global helpers available in all test files
- `eventually/2` - Retry assertions with timeout
- `assert_html/3` - Wait for text/regex in HTML
- `refute_html/3` - Wait for text/regex to disappear
- `assert_element/3` - Check element existence
- `refute_element/3` - Check element absence

**Mock Gateway** (`test/support/mock_gateway.ex`)
- Standalone Plug-based server
- Runs on `http://localhost:8081` (test environment)
- Implements all Gateway endpoints
- Uses ETS for state management
- Supports error simulation (`force_error`, specific IDs)

---

## 2. Mock Gateway Strategy

### 2.1 Core Principles

1. **All JSON responses use `json_response/3` helper**
   ```elixir
   defp json_response(conn, status, body) do
     conn
     |> put_resp_content_type("application/json")
     |> send_resp(status, Jason.encode!(body))
   end
   ```

2. **Request data from `conn.body_params` or `conn.query_params`**
   - Body params for POST/PUT/PATCH
   - Query params for GET with filters

3. **State stored in ETS tables**
   - Shared across all test processes
   - Reset in test `setup` blocks
   - Example: `:mock_gateway_deleted_ids` for tracking deletions

4. **Mock data matches real Gateway contracts**
   - Same response structure
   - Same field names and types
   - Same error formats

### 2.2 Endpoint Patterns

**List Endpoints** (GET with pagination)
```elixir
get "/api/v1/messages" do
  query = conn.query_params
  limit = to_int_default(Map.get(query, "limit"), 20)
  offset = to_int_default(Map.get(query, "offset"), 0) |> max(0)
  
  items = mock_messages()
    |> filter_by_status(Map.get(query, "status"))
    |> Enum.drop(offset)
    |> Enum.take(limit)
  
  json_response(conn, 200, %{
    data: items,
    pagination: %{
      total: length(mock_messages()),
      limit: limit,
      offset: offset,
      has_more: offset + limit < total
    }
  })
end
```

**Error Simulation**
```elixir
# Force error via query param
case Map.get(query, "status") do
  "force_error" ->
    json_response(conn, 500, %{"error" => "forced_error"})
  
  _ ->
    # Normal response
end

# Force error for specific ID
case id do
  "msg_fail" ->
    json_response(conn, 500, %{"error" => "delete_failed"})
  
  _ ->
    # Normal response
end
```

**Bulk Operations**
```elixir
post "/api/v1/messages/bulk_delete" do
  %{"ids" => ids} = conn.body_params
  
  # Store deleted IDs in ETS
  Enum.each(ids, fn id ->
    :ets.insert(@ets_table, {id, true})
  end)
  
  json_response(conn, 200, %{"deleted" => length(ids)})
end
```

### 2.3 Mock Data Structure

**Messages Mock Data**
- 60 messages: `msg_001` through `msg_060`
- Special IDs: `msg_fail` (fails on delete/export)
- Fields: `id`, `type`, `status`, `prompt`, `response`, `created_at`, etc.

**Extensions Mock Data**
- 40 extensions: `ext_001` through `ext_040`
- Special ID: `ext_fail` (fails on toggle/delete, appears first in list)
- Fields: `id`, `name`, `type`, `enabled`, `health`, `version`, etc.

**Key Points**
- Mock data is the source of truth for test expectations
- Tests should use actual IDs from mock data (`ext_001`, not `ext_openai_001`)
- Special IDs (`ext_fail`, `msg_fail`) are for error testing

---

## 3. LiveView Testing Patterns

### 3.1 Basic Test Structure

```elixir
defmodule UiWebWeb.MessagesLive.IndexTest do
  use UiWebWeb.LiveViewCase
  
  @moduletag :live_view
  @moduletag :integration
  
  setup do
    # Reset ETS state
    :ets.delete_all_objects(:mock_gateway_deleted_ids)
    :ok
  end
  
  test "renders messages list on load", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/app/messages")
    
    # Wait for async load using assert_html
    assert_html(view, "msg_001", timeout: 1000)
    
    html = render(view)
    assert html =~ "Messages"
    assert html =~ "msg_001"
  end
end
```

### 3.2 Forbidden Patterns

❌ **NEVER use `Process.sleep`**
```elixir
# BAD
Process.sleep(300)
html = render(view)

# GOOD
assert_html(view, "msg_001", timeout: 1000)
html = render(view)
```

❌ **NEVER check exact HTML structure**
```elixir
# BAD
assert html =~ "<div class=\"message\">msg_001</div>"

# GOOD
assert html =~ "msg_001"
```

❌ **NEVER use random or hardcoded IDs not in mock data**
```elixir
# BAD
assert html =~ "ext_openai_001"  # Not in mock data

# GOOD
assert html =~ "ext_001"  # From mock data
```

### 3.3 Required Test Coverage

**Happy Path**
- ✅ Initial load renders correctly
- ✅ Data appears from mock gateway
- ✅ Empty state when no data

**Filtering**
- ✅ Filter by status/type
- ✅ Filter updates list correctly
- ✅ Multiple filters work together

**Pagination**
- ✅ Navigate to next page
- ✅ Navigate to previous page
- ✅ Button states (disabled on boundaries)
- ✅ Correct items on each page

**Actions**
- ✅ Create/Update/Delete operations
- ✅ Toggle operations (for extensions)
- ✅ Bulk operations (delete, export)
- ✅ Success messages appear

**Error Handling**
- ✅ Error during list load
- ✅ Error during action (delete, toggle, etc.)
- ✅ Error messages displayed correctly
- ✅ UI recovers gracefully

**Polling** (for DashboardLive, PoliciesLive)
- ✅ Initial poll completes successfully
- ✅ Manual poll triggers update
- ✅ Polling continues after errors
- ✅ UI updates reflect new data

**Metrics and Health** (for DashboardLive)
- ✅ Component health extracted correctly
- ✅ Metrics normalized and displayed
- ✅ Health/metrics errors handled gracefully
- ✅ Dashboard continues to work if health/metrics fail

**Real-time Updates** (if applicable)
- ✅ PubSub events update UI
- ✅ Changes appear without refresh

### 3.4 Helper Usage Examples

**`assert_html` - Wait for text**
```elixir
# Simple text
assert_html(view, "msg_001", timeout: 1000)

# Regex pattern
assert_html(view, ~r/Extension|successfully|toggled/, timeout: 1000)

# With custom timeout
assert_html(view, "slow_loading_item", timeout: 5000)
```

**`refute_html` - Wait for text to disappear**
```elixir
# After delete
view |> element("button[phx-click='delete'][phx-value-id='msg_001']") |> render_click()
refute_html(view, "msg_001", timeout: 1000)
```

**`eventually` - Complex async assertions**
```elixir
eventually(fn ->
  html = render(view)
  assert html =~ "msg_001" && html =~ "completed"
end, timeout: 1000, interval: 50)
```

**`assert_element` / `refute_element` - Check DOM elements**
```elixir
assert_element(view, "button[phx-click='next_page']")
refute_element(view, "button[phx-click='prev_page']")  # Disabled on first page
```

---

## 4. Golden Examples

### 4.1 MessagesLive.Index

**File**: `test/ui_web_web/live/messages_live/index_test.exs`

**Key Tests**:
- ✅ Happy path: `"renders messages list on load"`
- ✅ Filtering: `"filters by status"`, `"filters by type"`
- ✅ Selection: `"shows bulk actions bar when messages selected"`
- ✅ Bulk delete: `"successful bulk delete"`
- ✅ Export: `"export JSON triggers download event"`
- ✅ Pagination: `"navigates between pages with Next/Previous"`
- ✅ Error handling: `"shows error flash when list_messages fails"`

**Patterns Used**:
```elixir
# Wait for load
assert_html(view, "msg_001", timeout: 1000)

# Filter
view
|> element("select[name='status']")
|> render_change(%{status: "completed"})
assert_html(view, "completed", timeout: 1000)

# Pagination
view |> element("button[phx-click='next_page']") |> render_click()
assert_html(view, "msg_021", timeout: 1000)  # First item on page 2
```

### 4.2 ExtensionsLive.Index

**File**: `test/ui_web_web/live/extensions_live/index_test.exs`

**Key Tests**:
- ✅ Happy path: `"displays extensions from mock gateway"`
- ✅ Filtering: `"filters by type"`, `"filters by status"`
- ✅ Toggle: `"toggles extension enabled/disabled"`
- ✅ Delete: `"deletes extension with confirmation"`
- ✅ Pagination: `"navigates between pages with Next/Previous"`
- ✅ Error handling: `"shows error flash when list_extensions fails"`

**Special Considerations**:
- `ext_fail` appears first in mock data (affects pagination)
- Page 1: `ext_fail`, `ext_001`..`ext_019` (20 items)
- Page 2: `ext_020`..`ext_039` (20 items)
- Tests account for `ext_fail` in pagination checks

**Patterns Used**:
```elixir
# Wait for load (account for ext_fail)
assert_html(view, ~r/ext_fail|ext_001/, timeout: 1000)

# Toggle with enabled parameter
view
|> element("button[phx-click='toggle_extension'][phx-value-id='ext_001']")
|> render_click()
assert_html(view, ~r/Extension|successfully|enabled/, timeout: 1000)
```

### 4.3 PoliciesLive

**File**: `test/ui_web_web/live/policies_live_test.exs`

**Key Tests**:
- ✅ Happy path: `"renders policies page"`, `"displays policy list after initial poll"`
- ✅ CRUD: `"loads a policy"`, `"saves a policy"`, `"deletes a policy"`
- ✅ Validation: `"validates JSON format in editor"`, `"accepts valid JSON"`
- ✅ Polling: `"polls for policies on mount"`, `"polls periodically for updates"`
- ✅ Error handling: `"displays error when Gateway returns error"`, `"handles save error for policy_fail"`

**Special Considerations**:
- Uses polling (15 second interval) for policy list updates
- JSON editor with validation (invalid JSON shows error)
- Tenant and Policy ID management via form
- Error simulation via `force_error` tenant or `policy_fail` ID

**Patterns Used**:
```elixir
# Wait for initial poll
assert_html(view, "tenant_dev", timeout: 2000)

# Load policy
view
|> element("button[phx-click='load']")
|> render_click()
assert_html(view, ~r/rules|"action"/, timeout: 1000)

# Save with JSON validation
view
|> form("form[phx-submit='save']", %{"editor" => policy_json})
|> render_submit()
refute_html(view, "Invalid JSON", timeout: 1000)

# Error handling for policy_fail
view
|> form("form[phx-change='set']", %{
  "tenant_id" => "tenant_dev",
  "policy_id" => "policy_fail"
})
|> render_change()
# ... trigger save/delete
assert_html(view, ~r/error|Error|Failed/i, timeout: 1000)
```

### 4.4 DashboardLive

**File**: `test/ui_web_web/live/dashboard_live_test.exs`

**Key Tests**:
- ✅ Happy path: `"renders dashboard with initial state"`, `"displays component health status after initial poll"`
- ✅ Polling: `"polls Gateway for health updates"`, `"updates metrics when Gateway returns new data"`
- ✅ Component health: `"extracts gateway health from response"`, `"extracts router health from response"`
- ✅ Metrics: `"displays throughput (rps)"`, `"displays latency metrics (p50, p95)"`, `"displays error rate"`
- ✅ Error handling: `"handles Gateway errors gracefully during polling"`, `"continues to poll after error"`

**Special Considerations**:
- Uses polling (5 second interval) for health and metrics updates
- Multiple data sources: `/_health` (components) and `/metrics` (performance)
- Metrics normalization (integer to float conversion)
- Graceful error handling (dashboard continues to work even if health/metrics fail)
- Component health extraction from nested health response

**Patterns Used**:
```elixir
# Wait for initial poll (health + metrics)
assert_html(view, ~r/ok|System Status|Component Health/, timeout: 2000)

# Trigger manual poll
send(view.pid, :tick)
assert_html(view, ~r/ok|System Status/, timeout: 2000)

# Check component health
assert_html(view, "C-Gateway", timeout: 2000)
assert_html(view, "Router", timeout: 2000)
assert_html(view, "NATS", timeout: 2000)

# Check metrics
assert_html(view, ~r/Throughput|req\/s/, timeout: 2000)
assert_html(view, "Latency", timeout: 2000)
assert_html(view, "Error Rate", timeout: 2000)

# Error handling (graceful - dashboard doesn't crash)
original_url = Application.get_env(:ui_web, :gateway) |> Keyword.get(:url)
Application.put_env(:ui_web, :gateway, url: "http://localhost:99999", timeout: 500)
try do
  send(view.pid, :tick)
  # Dashboard should still render (graceful error handling)
  assert_html(view, "Dashboard", timeout: 3000)
  html = render(view)
  assert html =~ "Dashboard"
after
  Application.put_env(:ui_web, :gateway, url: original_url, timeout: 5000)
  Process.sleep(200)
end
```

**Polling Pattern**:
```elixir
# Polling tests should:
# 1. Wait for initial poll to complete
assert_html(view, "expected_content", timeout: 2000)

# 2. Trigger manual poll (for testing)
send(view.pid, :tick)

# 3. Wait for update
assert_html(view, "updated_content", timeout: 2000)

# 4. Verify state changed
html1 = render(view)
# ... trigger poll ...
html2 = render(view)
assert html2 =~ "updated_content"
```

**Metrics Normalization Pattern**:
```elixir
# Mock Gateway returns integer values
# DashboardLive normalizes them to floats for display
# Tests should verify metrics appear correctly

# Wait for metrics to load
assert_html(view, "Real-time Metrics", timeout: 2000)

# Check specific metrics
assert_html(view, ~r/Throughput|req\/s/, timeout: 1000)
assert_html(view, "Latency", timeout: 1000)
assert_html(view, "Error Rate", timeout: 1000)
```

---

## 4.5 Quick Start: Writing a New LiveView Test

This section provides a step-by-step guide for creating tests for a new LiveView from scratch.

### Step 1: Analyze the LiveView

**Identify endpoints and data flow:**
```elixir
# Example: NewLiveView uses:
# - GET /api/v1/items - list items
# - POST /api/v1/items - create item
# - GET /api/v1/items/:id - get item
# - DELETE /api/v1/items/:id - delete item
```

**Identify key features:**
- Does it have filtering? (status, type, search)
- Does it have pagination? (limit/offset)
- Does it have bulk operations? (bulk_delete, export)
- Does it use polling? (periodic updates)
- Does it display metrics? (health, performance)

### Step 2: Add Mock Endpoints

**Add endpoints to `test/support/mock_gateway.ex`:**

```elixir
# List endpoint
get "/api/v1/items" do
  query = conn.query_params
  
  # Force error for testing
  case Map.get(query, "status") do
    "force_error" ->
      json_response(conn, 500, %{"error" => "forced_error"})
    
    _ ->
      limit = to_int_default(Map.get(query, "limit"), 20)
      offset = to_int_default(Map.get(query, "offset"), 0) |> max(0)
      
      items = mock_items()
        |> filter_by_status(Map.get(query, "status"))
      
      total = length(items)
      paginated = items
        |> Enum.drop(offset)
        |> Enum.take(limit)
      
      json_response(conn, 200, %{
        data: paginated,
        pagination: %{
          total: total,
          limit: limit,
          offset: offset,
          has_more: offset + limit < total
        }
      })
  end
end

# Create endpoint
post "/api/v1/items" do
  body = conn.body_params
  new_item = Map.put(body, "id", "item_#{System.unique_integer([:positive])}")
  json_response(conn, 201, new_item)
end

# Get by ID
get "/api/v1/items/:id" do
  item = Enum.find(mock_items(), fn i -> i["id"] == id end)
  case item do
    nil -> json_response(conn, 404, %{"error" => "Not found"})
    i -> json_response(conn, 200, i)
  end
end

# Delete endpoint
delete "/api/v1/items/:id" do
  case id do
    "item_fail" ->
      json_response(conn, 500, %{"error" => "delete_failed"})
    _ ->
      json_response(conn, 200, %{"deleted" => true})
  end
end
```

**Add mock data function:**
```elixir
defp mock_items do
  for i <- 1..50 do
    %{
      "id" => "item_#{i |> Integer.to_string() |> String.pad_leading(3, "0")}",
      "name" => "Item #{i}",
      "status" => Enum.at(~w(active inactive pending), rem(i, 3)),
      "created_at" => "2025-01-27T12:00:00Z"
    }
  end
end
```

### Step 3: Create Test File

**Create `test/ui_web_web/live/new_live/index_test.exs`:**

```elixir
defmodule UiWebWeb.NewLive.IndexTest do
  use UiWebWeb.LiveViewCase
  
  @moduletag :live_view
  @moduletag :integration
  
  setup do
    # Reset ETS state if needed
    :ok
  end
  
  describe "loading items" do
    test "renders items list on load", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/items")
      
      # Wait for initial load
      assert_html(view, "item_001", timeout: 1000)
      
      assert html =~ "Items"
      assert html =~ "item_001"
    end
  end
end
```

### Step 4: Add Basic Tests

**Happy path:**
```elixir
test "renders items list on load", %{conn: conn} do
  {:ok, view, html} = live(conn, ~p"/app/items")
  assert_html(view, "item_001", timeout: 1000)
  assert html =~ "Items"
end
```

**Filtering (if applicable):**
```elixir
test "filters by status", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/items")
  
  view
  |> element("select[name='status']")
  |> render_change(%{status: "active"})
  
  assert_html(view, "active", timeout: 1000)
  refute_html(view, "inactive", timeout: 1000)
end
```

**Pagination (if applicable):**
```elixir
test "navigates between pages", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/items")
  
  assert_html(view, "item_001", timeout: 1000)
  refute_html(view, "item_021", timeout: 1000)
  
  view |> element("button[phx-click='next_page']") |> render_click()
  
  assert_html(view, "item_021", timeout: 1000)
  refute_html(view, "item_001", timeout: 1000)
end
```

**Actions (create/update/delete):**
```elixir
test "creates new item", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/items")
  
  view
  |> form("form[phx-submit='save']", %{"name" => "New Item"})
  |> render_submit()
  
  assert_html(view, ~r/Item.*created|success/i, timeout: 1000)
end
```

### Step 5: Add Error Flows

**Error during list load:**
```elixir
test "shows error when list fails", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/items?status=force_error")
  
  assert_html(view, ~r/error|Error|Failed/i, timeout: 2000)
end
```

**Error during action:**
```elixir
test "handles delete error", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/items")
  
  view
  |> element("button[phx-click='delete'][phx-value-id='item_fail']")
  |> render_click()
  
  assert_html(view, ~r/error|Error|Failed/i, timeout: 1000)
end
```

### Step 6: Add Polling/Metrics (if applicable)

**Polling:**
```elixir
test "polls for updates", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/items")
  
  # Wait for initial poll
  assert_html(view, "item_001", timeout: 2000)
  
  # Trigger manual poll
  send(view.pid, :tick)
  
  # Wait for update
  assert_html(view, "item_001", timeout: 2000)
end
```

**Metrics:**
```elixir
test "displays metrics", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/items")
  
  assert_html(view, "Real-time Metrics", timeout: 2000)
  assert_html(view, ~r/Throughput|req\/s/, timeout: 1000)
end
```

### Step 7: Use Helpers

**Always use helpers instead of `Process.sleep`:**
```elixir
# ❌ BAD
Process.sleep(300)
html = render(view)

# ✅ GOOD
assert_html(view, "expected_text", timeout: 1000)
html = render(view)
```

**Use `assert_element` for DOM checks:**
```elixir
# ✅ GOOD
assert_element(view, "button[phx-click='next_page']")
refute_element(view, "button[phx-click='prev_page']")
```

### Step 8: Verify and Document

**Run tests:**
```bash
mix test test/ui_web_web/live/new_live/index_test.exs --include live_view
```

**Verify all tests pass:**
- ✅ No `Process.sleep` calls
- ✅ All async operations use `assert_html`/`eventually`
- ✅ Error flows tested
- ✅ Mock data matches test expectations

**Add to Golden Examples:**
- Update `docs/UI_WEB_TEST_STRATEGY.md` section 4
- Add key tests and patterns used
- Document special considerations

### Checklist

Before considering a LiveView test complete:

- [ ] Mock endpoints added to `mock_gateway.ex`
- [ ] Mock data function created
- [ ] Happy path test passes
- [ ] Filtering tests (if applicable)
- [ ] Pagination tests (if applicable)
- [ ] Action tests (create/update/delete)
- [ ] Error flow tests
- [ ] Polling tests (if applicable)
- [ ] Metrics tests (if applicable)
- [ ] No `Process.sleep` calls
- [ ] All tests use `assert_html`/`eventually`
- [ ] Tests pass consistently
- [ ] Added to Golden Examples in Test Strategy

---

## 5. Running and Debugging Tests

### 5.1 Running Tests

**Single test file**
```bash
mix test test/ui_web_web/live/messages_live/index_test.exs --include live_view
```

**All LiveView tests**
```bash
mix test --include live_view
```

**Specific test**
```bash
mix test test/ui_web_web/live/messages_live/index_test.exs:18 --include live_view
```

**With tracing**
```bash
mix test test/ui_web_web/live/messages_live/index_test.exs --include live_view --trace
```

### 5.2 Debugging Failed Tests

**Check Mock Gateway**
```bash
curl http://localhost:8081/health
curl http://localhost:8081/api/v1/messages
```

**Inspect HTML in test**
```elixir
html = render(view)
IO.puts(html)  # Print full HTML
```

**Check ETS state**
```elixir
# In test or IEx
:ets.tab2list(:mock_gateway_deleted_ids)
```

**Verify authentication**
```elixir
# In test
conn = build_conn()
# Check Guardian token is set
```

### 5.3 Common Issues

**Mock Gateway not running**
- Error: `(Mint.TransportError) connection refused`
- Solution: Ensure Mock Gateway starts in `test_helper.exs`
- Check: `curl http://localhost:8081/health`

**Authentication failures**
- Error: `(Phoenix.LiveViewTest.UnauthorizedError)`
- Solution: `LiveViewCase` sets up authentication automatically
- Verify: Check `setup` block in `LiveViewCase`

**Tests timing out**
- Error: `eventually` timeout exceeded
- Solution: Increase timeout or check mock endpoint response
- Debug: Add `IO.puts(render(view))` to see actual HTML

**State pollution between tests**
- Issue: Previous test affects current test
- Solution: Reset ETS in `setup` block
- Example: `:ets.delete_all_objects(:mock_gateway_deleted_ids)`

---

## 6. Best Practices

### 6.1 Test Organization

- Group related tests in `describe` blocks
- Use descriptive test names: `"filters by status"` not `"test1"`
- Keep tests independent (no shared state between tests)
- Reset state in `setup` blocks

### 6.2 Assertions

- Use semantic assertions: `assert html =~ "msg_001"` not `assert html =~ "<div>"`
- Wait for async operations: `assert_html(view, "text")` not `Process.sleep(300)`
- Check both presence and absence: `assert` + `refute`
- Use regex for flexible matching: `~r/Extension|successfully/`

### 6.3 Mock Data

- Mock data is the source of truth
- Use actual IDs from mock data in tests
- Document special IDs (`ext_fail`, `msg_fail`) and their purpose
- Keep mock data consistent across tests

### 6.4 Error Testing

- Test both client errors and server errors
- Use `force_error` query param for list errors
- Use special IDs (`ext_fail`, `msg_fail`) for action errors
- Verify error messages are user-friendly (via `GatewayErrorHelper`)

---

## 7. Migration Guide

### 7.1 Converting Old Tests

**Before (with `Process.sleep`)**
```elixir
test "loads messages" do
  {:ok, view, _html} = live(conn, ~p"/app/messages")
  Process.sleep(300)
  html = render(view)
  assert html =~ "msg_001"
end
```

**After (with `assert_html`)**
```elixir
test "loads messages" do
  {:ok, view, _html} = live(conn, ~p"/app/messages")
  assert_html(view, "msg_001", timeout: 1000)
  html = render(view)
  assert html =~ "msg_001"
end
```

### 7.2 Adding Tests to New LiveView

1. **Create test file**: `test/ui_web_web/live/your_live/index_test.exs`
2. **Use `LiveViewCase`**: `use UiWebWeb.LiveViewCase`
3. **Add tags**: `@moduletag :live_view` and `@moduletag :integration`
4. **Reset state in setup**: Clear ETS tables if needed
5. **Follow patterns**: Use `assert_html`, `eventually`, etc.
6. **Sync with mock data**: Use actual IDs from mock gateway

---

## 8. Client Layer Normalization

### 8.1 Overview

The client layer (`UiWeb.Services.*Client`) has been unified to use a common normalization layer (`UiWeb.Services.ClientHelpers`). This ensures consistent error handling, response formatting, and query parameter building across all Gateway API clients.

### 8.2 ClientHelpers Module

**Location**: `lib/ui_web/services/client_helpers.ex`

**Key Functions**:

1. **`build_query_params/1`**
   - Filters out `nil` and empty string values
   - Converts keyword list to map
   - Used by all clients for query parameter building

2. **`normalize_response/1`**
   - Handles Gateway response normalization
   - Converts `{:ok, %{"error" => _}}` to error tuple
   - Handles empty bodies (204 No Content)
   - Decodes JSON strings automatically
   - Preserves HTTP and network errors

3. **`handle_delete_response/1`**
   - Converts `{:ok, _}` to `:ok` for delete operations
   - Preserves error tuples
   - Ensures consistent delete operation return values

4. **`extract_items/1`**
   - Extracts items from paginated responses
   - Handles `%{"data" => items}`, `%{"items" => items}`, and direct lists
   - Returns empty list for invalid input

### 8.3 Unified Client Pattern

All clients (`MessagesClient`, `ExtensionsClient`, etc.) now follow the same pattern:

```elixir
alias UiWeb.Services.GatewayClient
alias UiWeb.Services.ClientHelpers

def list_resources(opts \\ []) do
  query_params = ClientHelpers.build_query_params(opts)
  GatewayClient.get_json("/api/v1/resources", params: query_params)
end

def delete_resource(id) do
  GatewayClient.delete("/api/v1/resources/#{id}")
end
```

### 8.4 Response Normalization

**GatewayClient** automatically normalizes all responses through `ClientHelpers.normalize_response/1`:

- Success responses: `{:ok, body}` (map, list, or binary)
- Error in body: `{:ok, %{"error" => msg}}` → `{:error, %{reason: :gateway_error, ...}}`
- HTTP errors: `{:error, {:http_error, status, body}}`
- Network errors: `{:error, reason}` (timeout, connection refused, etc.)
- Empty body: `{:ok, ""}` → `{:ok, %{}}`

### 8.5 Testing Client Layer

**Unit Tests** (`test/ui_web/services/*_client_test.exs`):
- Test individual client functions
- Verify query parameter building
- Test error handling
- Mock Gateway responses

**ClientHelpers Tests** (`test/ui_web/services/client_helpers_test.exs`):
- Test normalization logic
- Test query parameter filtering
- Test delete response handling
- Test item extraction

**Integration Tests** (LiveView tests):
- Test full flow: LiveView → Client → Mock Gateway
- Verify normalized responses work correctly
- Test error handling in UI

### 8.6 Error Format

All clients return consistent error formats:

```elixir
# Gateway error in body
{:error, %{reason: :gateway_error, details: %{"error" => "..."}, message: "..."}}

# HTTP error
{:error, {:http_error, 404, %{"error" => "Not found"}}}

# Network error
{:error, :timeout}
{:error, :econnrefused}
```

**GatewayErrorHelper** handles all these formats for user-friendly messages.

### 8.7 Benefits

1. **Consistency**: All clients use the same patterns
2. **Maintainability**: Common logic in one place
3. **Error Handling**: Unified error format across all clients
4. **Testing**: Easier to test and mock
5. **Code Reduction**: ~30-40% less duplication

### 8.8 Migration Notes

When adding a new client:
1. Use `ClientHelpers.build_query_params/1` for query parameters
2. Use `GatewayClient.get_json/post_json/put_json/delete` methods
3. Let `GatewayClient` handle normalization automatically
4. Use `GatewayErrorHelper.format_gateway_error/1` for UI error messages

## 9. References

### Quick Start Guide

- **[TESTING_QUICKSTART.md](./TESTING_QUICKSTART.md)** - Quick reference for writing and running tests

### Contract Testing

- **[CONTRACT_TESTING.md](./CONTRACT_TESTING.md)** - Mock Gateway as API specification

### Documentation

- **[UI_WEB_GATEWAY_INTEGRATION.md](./UI_WEB_GATEWAY_INTEGRATION.md)** - Gateway HTTP integration details
- **[UI_WEB_REALTIME.md](./UI_WEB_REALTIME.md)** - Real-time updates via NATS

### Code References

- `test/support/live_view_case.ex` - Base test case for LiveView tests
- `test/support/test_helpers.ex` - Test helpers (`assert_html`, `eventually`, etc.)
- `test/support/mock_gateway.ex` - Mock Gateway implementation
- `lib/ui_web/services/client_helpers.ex` - Client normalization helpers
- `lib/ui_web/services/gateway_client.ex` - Gateway HTTP client

### Golden Examples (Test Files)

- `test/ui_web_web/live/messages_live/index_test.exs` - Full CRUD, filtering, pagination, bulk operations
- `test/ui_web_web/live/extensions_live/index_test.exs` - CRUD, toggle, filtering, pagination
- `test/ui_web_web/live/policies_live_test.exs` - CRUD, JSON validation, polling
- `test/ui_web_web/live/dashboard_live_test.exs` - Polling, metrics, health, error handling

### Golden Examples (LiveView Code)

- `lib/ui_web_web/live/messages_live/index.ex` - MessagesLive.Index implementation
- `lib/ui_web_web/live/extensions_live/index.ex` - ExtensionsLive.Index implementation
- `lib/ui_web_web/live/policies_live.ex` - PoliciesLive implementation
- `lib/ui_web_web/live/dashboard_live.ex` - DashboardLive implementation

- **Test Helpers**: `test/support/test_helpers.ex`
- **LiveView Case**: `test/support/live_view_case.ex`
- **Mock Gateway**: `test/support/mock_gateway.ex`
- **Golden Examples**:
  - `test/ui_web_web/live/messages_live/index_test.exs` - Messages CRUD, filtering, pagination
  - `test/ui_web_web/live/extensions_live/index_test.exs` - Extensions CRUD, toggle, filtering
  - `test/ui_web_web/live/policies_live_test.exs` - Policies CRUD, JSON validation, polling
  - `test/ui_web_web/live/dashboard_live_test.exs` - Dashboard polling, metrics, health
- **Gateway Integration**: `docs/UI_WEB_GATEWAY_INTEGRATION.md`
- **Real-time Updates**: `docs/UI_WEB_REALTIME.md`

---

## 9. Summary

**Key Principles**:
1. ✅ Use `assert_html`/`eventually` instead of `Process.sleep`
2. ✅ Mock Gateway is the source of truth for test data
3. ✅ Tests should be independent and reset state
4. ✅ Follow patterns from golden examples (Messages, Extensions, Policies, Dashboard)
5. ✅ Test happy path, filters, pagination, actions, errors, and polling

**Success Criteria**:
- All tests pass without `Process.sleep`
- Tests use `assert_html`/`eventually` for async operations
- Mock Gateway endpoints match real Gateway contracts
- Tests are readable and maintainable
- New LiveViews follow the same patterns
- Polling and metrics tests handle errors gracefully

**Current Status**:
- ✅ **4 golden examples** with complete test coverage:
  - MessagesLive.Index (CRUD, filtering, pagination, bulk operations)
  - ExtensionsLive.Index (CRUD, toggle, filtering, pagination)
  - PoliciesLive (CRUD, JSON validation, polling)
  - DashboardLive (polling, metrics, health, error handling)
- ✅ **Unified test patterns** across all LiveViews
- ✅ **Unified client layer** with `ClientHelpers` normalization
- ✅ **Production-grade test framework** ready for scaling

---

*Last updated: 2025-01-27*
*Based on: MessagesLive.Index, ExtensionsLive.Index, PoliciesLive, and DashboardLive implementations*

