# Selection + Bulk Actions Tests - Technical Specification

**File:** `apps/ui_web/test/ui_web_web/live/messages_live/index_test.exs`

**Goal:** Verify and document the correct behavior of message selection and bulk actions (bulk operations).

Tests must guarantee:

1. Correct appearance/disappearance of Bulk actions panel.
2. Correct successful `bulk_delete`.
3. Correct error display on failed `bulk_delete`.

Tests work through mock-Gateway.

---

## 4. Selection + Bulk Actions

### 4.1. Bulk Bar Appearance

**What to verify:**

- Panel appears only after selecting at least one message.
- Panel text: `"<N> message(s) selected"`.
- Panel buttons:
  - **Export JSON**
  - **Export CSV**
  - **Delete Selected**
  - **Clear selection**

**Prerequisites:**

Template contains:

```heex
<input type="checkbox" phx-click="toggle_select" phx-value-id="msg_001" />
```

```heex
<%= if MapSet.size(@selected_ids) > 0 do %>
  <div>
    <div><%= MapSet.size(@selected_ids) %> message(s) selected</div>
    <!-- buttons -->
  </div>
<% end %>
```

Fixture data contains `msg_001`.

**Test:**

```elixir
describe "selection and bulk actions" do
  test "shows bulk actions bar when a message is selected", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/app/messages")
    refute html =~ "message(s) selected"

    html =
      view
      |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
      |> render_click()

    assert html =~ "message(s) selected"
    assert html =~ "Export JSON"
    assert html =~ "Export CSV"
    assert html =~ "Delete Selected"
    assert html =~ "Clear selection"
  end
end
```

**Status:** ✅ Implemented

---

### 4.2. Successful bulk_delete

**What to verify:**

- Selection panel is already shown.
- After clicking `Delete Selected`:
  - Flash message appears: `"Deleted"` or `"Deleted N messages"`;
  - Message disappears from table;
  - Selected IDs are cleared.

**Prerequisites:**

Mock Gateway:

```elixir
post "/api/v1/messages/bulk_delete" do
  {:ok, body, conn} = Plug.Conn.read_body(conn)
  {:ok, %{"message_ids" => ids}} = Jason.decode(body)

  send_resp(conn, 200, Jason.encode!(%{
    "deleted_count" => length(ids),
    "failed" => []
  }))
end
```

LiveView:
- Calls Gateway client;
- On success:
  - Clears `@selected_ids`;
  - Removes messages from `@messages`;
  - Shows flash.

**Test:**

```elixir
test "bulk delete removes selected messages on success", %{conn: conn} do
  {:ok, view, html} = live(conn, ~p"/app/messages")
  assert html =~ "msg_001"

  view
  |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_001']")
  |> render_click()

  html =
    view
    |> element("button[phx-click='bulk_delete']")
    |> render_click()

  assert html =~ "Deleted"
  refute html =~ "msg_001"
end
```

**Status:** ✅ Implemented

---

### 4.3. Error bulk_delete (`msg_fail`)

**What to verify:**

- On error:
  - Flash message shown: `"Bulk delete failed"`;
  - Message remains in DOM;
  - Selected IDs unchanged.

**Prerequisites:**

Fixture data contains `msg_fail`.

Mock Gateway:

```elixir
if "msg_fail" in ids do
  send_resp(conn, 500, Jason.encode!(%{
    "deleted_count" => 0,
    "failed" => ["msg_fail"]
  }))
else
  send_resp(conn, 200, Jason.encode!(%{
    "deleted_count" => length(ids),
    "failed" => []
  }))
end
```

LiveView:
- On error calls `put_flash(:error, "Bulk delete failed")`;
- Message list unchanged.

**Test:**

```elixir
test "shows error when bulk delete fails", %{conn: conn} do
  {:ok, view, html} = live(conn, ~p"/app/messages")
  assert html =~ "msg_fail"

  view
  |> element("input[type='checkbox'][phx-click='toggle_select'][phx-value-id='msg_fail']")
  |> render_click()

  html =
    view
    |> element("button[phx-click='bulk_delete']")
    |> render_click()

  assert html =~ "Bulk delete failed"
  assert html =~ "msg_fail"
end
```

**Status:** ✅ Implemented

---

## Summary

**Block is considered complete when all tests pass:**

1. ✅ **Bulk panel appearance** - UI reacts when at least one message is selected.
2. ✅ **Successful bulk_delete** - Removes rows and shows confirmation.
3. ✅ **Error bulk_delete** - Shows error, does not remove rows.

These tests fully cover the risk of regressions and document the UI contract for `MessagesLive.Index`.

---

## Test Implementation Details

### Current Implementation

All three tests are implemented in:
- `test/ui_web_web/live/messages_live/index_test.exs`
- Lines: 88-174 (selection and bulk actions)
- Lines: 364-401 (bulk delete errors)

### Test Coverage

- ✅ Bulk bar appearance/disappearance
- ✅ Successful bulk delete with flash message
- ✅ Error handling for bulk delete
- ✅ Selection clearing (deselect_all)

### Mock Gateway Integration

Tests use `UiWeb.Test.MockGateway` which:
- Handles `POST /api/v1/messages/bulk_delete`
- Returns success (200) for normal messages
- Returns error (500) for `msg_fail` ID
- Maintains deleted message IDs in ETS table

### Async Handling

Tests use `eventually/2` helper for:
- Waiting for async operations (bulk delete)
- Handling LiveView re-renders
- Ensuring UI state updates are captured

---

## References

- Test file: `apps/ui_web/test/ui_web_web/live/messages_live/index_test.exs`
- Mock Gateway: `apps/ui_web/test/support/mock_gateway.ex`
- LiveView implementation: `apps/ui_web/lib/ui_web_web/live/messages_live/index.ex`

