# Export Tests - Technical Specification

**File:** `apps/ui_web/test/ui_web_web/live/messages_live/index_test.exs`

**Goal:** Cover the entire Export block: no crashes, selection preservation, correct `push_event("download")`, optional error handling.

---

## 1. What Needs to be Tested

### 1.1. Basic Scenario - Export Does Not Break LiveView

**Guarantees:**
- LiveView remains alive after clicking Export
- Selection state (`selected_ids`) is preserved
- Bulk panel continues to display
- No `** (exit)`/`{:error, ...}` errors during render

### 1.2. Export → push_event("download", payload)

**If `handle_event("export", ...)` uses `push_event`:**
- Must send `download` event
- Payload must contain correct format (`mime_type`, `filename`, `content`)
- Event can be verified via `assert_push_event/3`

### 1.3. Export Error Path (Optional)

**On error:**
- LiveView should render `put_flash(:error, ...)`
- Bulk panel may remain or disappear - document desired behavior

Mock Gateway should be able to simulate 500, e.g., via id `msg_fail_export`.

---

## 2. Prerequisites / Conditions

### 2.1. Index Template Contains Export Buttons

```heex
<button phx-click="export" phx-value-format="json">Export JSON</button>
<button phx-click="export" phx-value-format="csv">Export CSV</button>
```

### 2.2. LiveView

In `handle_event("export", %{"format" => format}, socket)`:
- Collect `selected_ids` from assigns
- Call `MessagesClient.export_messages(ids, format)`
- On success: `push_event("download", %{...})`
- On error: `put_flash(:error, ...)`

### 2.3. Mock Gateway

Routes:
```
POST /api/v1/messages/export
→ Returns content directly (JSON/CSV binary)
→ If ids includes "msg_fail_export", return 500
```

---

## 3. Test Cases

### 3.1. Test: Export Does Not Break LiveView and Preserves Selection

**Goal:** Basic stability guarantee.

**Expected Behavior:**
- Before export: select msg_001 → bulk panel visible
- After clicking Export → bulk panel still visible
- No exceptions

**Test:**
```elixir
describe "export" do
  test "export does not crash and keeps selection", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/app/messages")
    
    # Выбираем сообщение
    view
    |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
    |> render_click()
    
    # Подтверждаем, что панель есть
    assert render(view) =~ "message(s) selected"
    
    # Запускаем export
    html =
      view
      |> element("button[phx-click='export'][phx-value-format='json']")
      |> render_click()
    
    # Ждём push event
    assert_push_event(view, "download", %{mime_type: "application/json"})
    
    # Выбор остался
    assert html =~ "message(s) selected"
  end
end
```

**Status:** ✅ Implemented (line 173-198)

---

### 3.2. Test: Export Triggers `push_event("download", payload)`

**Goal:** Guarantee that LiveView sends event to client.

**Expected Behavior:**
- After clicking Export, `push_event "download"` must appear

**Test:**
```elixir
test "export triggers download event with correct payload", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/messages")
  
  view
  |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
  |> render_click()
  
  view
  |> element("button[phx-click='export'][phx-value-format='json']")
  |> render_click()
  
  assert_push_event(view, "download", payload)
  
  assert payload.mime_type == "application/json"
  assert is_binary(payload.filename)
  assert is_binary(payload.content)
  assert payload.filename =~ ".json"
end
```

**Status:** ✅ Implemented (line 200-223)

---

### 3.3. Test: Export Error (Optional)

**Goal:** Cover negative scenario.

**Prerequisite:**
Mock Gateway returns 500 if ids includes `"msg_fail_export"`.

**Expected Behavior:**
- Flash message appears: `"Export failed"`

**Test:**
```elixir
test "shows error when export fails", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/app/messages")
  
  view
  |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_fail_export']")
  |> render_click()
  
  html =
    view
    |> element("button[phx-click='export'][phx-value-format='json']")
    |> render_click()
  
  assert html =~ "Export failed"
end
```

**Status:** ✅ Implemented (line 436-463)

---

## 4. Acceptance Criteria

✅ **In `index_test.exs` there is at least 1 test:**
- ✅ Basic (`export does not crash and keeps selection`)
- ✅ With `push_event("download")`

✅ **If code has error handling branch - error-path test included**

✅ **All tests work with mock_gateway** (no external dependencies)

✅ **Selection after export is not reset**

✅ **No LiveView crashes**

---

## Implementation Details

### Current Implementation

All three tests are implemented in:
- `test/ui_web_web/live/messages_live/index_test.exs`
- Lines: 172-247 (export success tests)
- Lines: 436-463 (export error test)

### Test Coverage

- ✅ Export does not crash and keeps selection
- ✅ Export triggers download event with correct payload (JSON)
- ✅ Export CSV triggers download event
- ✅ Export error handling (msg_fail_export)

### Mock Gateway Integration

Tests use `UiWeb.Test.MockGateway` which:
- Handles `POST /api/v1/messages/export`
- Returns content directly (JSON/CSV binary) for success
- Returns error (500) for `msg_fail_export` ID
- Supports both JSON and CSV formats

### LiveView Implementation

`handle_event("export", %{"format" => format}, socket)`:
- Collects `selected_ids` from assigns
- Calls `MessagesClient.export_messages(ids, format)`
- On success: `push_event("download", %{content: Base64, filename, mime_type})`
- On error: `put_flash(:error, "Export failed. ...")`
- **Important:** Does NOT clear `selected_ids` (selection preserved)

### Payload Structure

The `push_event("download", payload)` contains:
- `mime_type`: `"application/json"` or `"text/csv"`
- `filename`: Generated filename with timestamp and format extension
- `content`: Base64-encoded export content

---

## References

- Test file: `apps/ui_web/test/ui_web_web/live/messages_live/index_test.exs`
- Mock Gateway: `apps/ui_web/test/support/mock_gateway.ex`
- LiveView implementation: `apps/ui_web/lib/ui_web_web/live/messages_live/index.ex`
- MessagesClient: `apps/ui_web/lib/ui_web/services/messages_client.ex`

