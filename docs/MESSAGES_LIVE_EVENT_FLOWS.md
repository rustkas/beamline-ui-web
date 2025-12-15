# MessagesLive.Index Event Flow Diagrams

This document describes the event flow diagrams for Filters, Bulk Actions, and Pagination in `MessagesLive.Index`.

## 1. Filter Flow

### 1.1. Filter by Status

```mermaid
sequenceDiagram
    participant User
    participant LiveView
    participant Router
    participant MessagesClient
    participant MockGateway

    User->>LiveView: Change <select name="status"> to "completed"
    LiveView->>LiveView: handle_event("filter_status", %{"status" => "completed"})
    LiveView->>Router: push_patch(to: "/app/messages?status=completed")
    Router->>LiveView: handle_params(params, url, socket)
    LiveView->>LiveView: assign(:filter_status, "completed")
    LiveView->>LiveView: load_messages()
    LiveView->>MessagesClient: list_messages(status: "completed", ...)
    MessagesClient->>MockGateway: GET /api/v1/messages?status=completed&limit=50&offset=0
    MockGateway->>MockGateway: filter_messages_by_status(messages, "completed")
    MockGateway-->>MessagesClient: 200 OK {data: [...], pagination: {...}}
    MessagesClient-->>LiveView: {:ok, %{data: [...], pagination: {...}}}
    LiveView->>LiveView: assign(:messages, data)
    LiveView->>LiveView: assign(:pagination, pagination)
    LiveView->>User: Render updated table with filtered messages
```

### 1.2. Filter by Type

```mermaid
sequenceDiagram
    participant User
    participant LiveView
    participant Router
    participant MessagesClient
    participant MockGateway

    User->>LiveView: Change <select name="type"> to "chat"
    LiveView->>LiveView: handle_event("filter_type", %{"type" => "chat"})
    LiveView->>Router: push_patch(to: "/app/messages?type=chat")
    Router->>LiveView: handle_params(params, url, socket)
    LiveView->>LiveView: assign(:filter_type, "chat")
    LiveView->>LiveView: load_messages()
    LiveView->>MessagesClient: list_messages(type: "chat", ...)
    MessagesClient->>MockGateway: GET /api/v1/messages?type=chat&limit=50&offset=0
    MockGateway->>MockGateway: filter_messages_by_type(messages, "chat")
    MockGateway-->>MessagesClient: 200 OK {data: [...], pagination: {...}}
    MessagesClient-->>LiveView: {:ok, %{data: [...], pagination: {...}}}
    LiveView->>LiveView: assign(:messages, data)
    LiveView->>User: Render updated table with filtered messages
```

## 2. Bulk Actions Flow

### 2.1. Selection Flow

```mermaid
stateDiagram-v2
    [*] --> NoSelection: Initial state
    NoSelection --> SelectionActive: User clicks checkbox
    SelectionActive --> SelectionActive: User clicks another checkbox
    SelectionActive --> NoSelection: User clicks "Clear Selection"
    SelectionActive --> BulkDelete: User clicks "Delete Selected"
    SelectionActive --> BulkExport: User clicks "Export JSON/CSV"
    BulkDelete --> NoSelection: Delete successful
    BulkDelete --> SelectionActive: Delete failed (error flash)
    BulkExport --> SelectionActive: Export successful (push_event)
    BulkExport --> SelectionActive: Export failed (error flash)
```

### 2.2. Bulk Delete Flow

```mermaid
sequenceDiagram
    participant User
    participant LiveView
    participant MessagesClient
    participant MockGateway

    User->>LiveView: Click "Delete Selected" button
    LiveView->>LiveView: handle_event("bulk_delete", %{})
    LiveView->>LiveView: Extract selected_ids from MapSet
    alt selected_ids is empty
        LiveView->>User: Flash warning: "No messages selected"
    else selected_ids not empty
        LiveView->>MessagesClient: bulk_delete_messages(ids)
        MessagesClient->>MockGateway: POST /api/v1/messages/bulk_delete<br/>{message_ids: ["msg_001", "msg_fail"]}
        MockGateway->>MockGateway: Split failed (msg_fail) and successful
        MockGateway->>MockGateway: delete_mock_message(id) for each
        alt All deletions successful
            MockGateway-->>MessagesClient: 200 OK {deleted_count: 2, failed: []}
            MessagesClient-->>LiveView: {:ok, %{"deleted_count" => 2}}
            LiveView->>LiveView: put_flash(:info, "Deleted 2 messages")
            LiveView->>LiveView: assign(:selected_ids, MapSet.new())
            LiveView->>LiveView: load_messages()
            LiveView->>User: Render updated table (messages removed)
        else Some deletions failed
            MockGateway-->>MessagesClient: 500 Error {deleted_count: 1, failed: ["msg_fail"]}
            MessagesClient-->>LiveView: {:error, %{reason: :gateway_error, ...}}
            LiveView->>LiveView: put_flash(:error, "Bulk delete failed. ...")
            LiveView->>User: Render error flash (messages remain selected)
        end
    end
```

### 2.3. Export Flow

```mermaid
sequenceDiagram
    participant User
    participant LiveView
    participant MessagesClient
    participant MockGateway
    participant Browser

    User->>LiveView: Click "Export JSON" button
    LiveView->>LiveView: handle_event("export", %{"format" => "json"})
    LiveView->>LiveView: Extract selected_ids from MapSet
    alt selected_ids is empty
        LiveView->>User: Flash warning: "No messages selected"
    else selected_ids not empty
        LiveView->>MessagesClient: export_messages(ids, "json")
        MessagesClient->>MockGateway: POST /api/v1/messages/export<br/>{message_ids: [...], format: "json"}
        MockGateway->>MockGateway: Fetch messages by IDs
        MockGateway->>MockGateway: Encode as JSON/CSV
        alt Export successful
            MockGateway-->>MessagesClient: 200 OK (content, content_type)
            MessagesClient-->>LiveView: {:ok, content}
            LiveView->>LiveView: push_event("download", %{content: Base64, filename, mime_type})
            LiveView->>Browser: JavaScript: trigger download
            Browser->>User: File download starts
            LiveView->>User: Selection preserved (bulk bar still visible)
        else Export failed
            MockGateway-->>MessagesClient: 500 Error
            MessagesClient-->>LiveView: {:error, reason}
            LiveView->>LiveView: put_flash(:error, "Export failed. ...")
            LiveView->>User: Render error flash
        end
    end
```

## 3. Pagination Flow

### 3.1. Next Page Flow

```mermaid
sequenceDiagram
    participant User
    participant LiveView
    participant MessagesClient
    participant MockGateway

    Note over LiveView: Current state: offset=0, limit=50
    User->>LiveView: Click "Next" button
    LiveView->>LiveView: handle_event("next_page", %{})
    LiveView->>LiveView: Calculate new_offset = offset + limit (50)
    LiveView->>LiveView: update(:pagination, fn pag -> Map.put(pag, "offset", 50) end)
    LiveView->>LiveView: load_messages()
    LiveView->>MessagesClient: list_messages(limit: 50, offset: 50, ...)
    MessagesClient->>MockGateway: GET /api/v1/messages?limit=50&offset=50&...
    MockGateway->>MockGateway: Enum.drop(messages, 50)
    MockGateway->>MockGateway: Enum.take(paginated, 50)
    MockGateway-->>MessagesClient: 200 OK {data: [msg_060, ...], pagination: {offset: 50, has_more: true}}
    MessagesClient-->>LiveView: {:ok, %{data: [...], pagination: {...}}}
    LiveView->>LiveView: assign(:messages, data)
    LiveView->>LiveView: assign(:pagination, pagination)
    LiveView->>User: Render page 2 (msg_060 visible, msg_001 not visible)
```

### 3.2. Previous Page Flow

```mermaid
sequenceDiagram
    participant User
    participant LiveView
    participant MessagesClient
    participant MockGateway

    Note over LiveView: Current state: offset=50, limit=50
    User->>LiveView: Click "Previous" button
    LiveView->>LiveView: handle_event("prev_page", %{})
    LiveView->>LiveView: Calculate new_offset = max(0, offset - limit) (0)
    LiveView->>LiveView: update(:pagination, fn pag -> Map.put(pag, "offset", 0) end)
    LiveView->>LiveView: load_messages()
    LiveView->>MessagesClient: list_messages(limit: 50, offset: 0, ...)
    MessagesClient->>MockGateway: GET /api/v1/messages?limit=50&offset=0&...
    MockGateway->>MockGateway: Enum.drop(messages, 0)
    MockGateway->>MockGateway: Enum.take(paginated, 50)
    MockGateway-->>MessagesClient: 200 OK {data: [msg_001, ...], pagination: {offset: 0, has_more: true}}
    MessagesClient-->>LiveView: {:ok, %{data: [...], pagination: {...}}}
    LiveView->>LiveView: assign(:messages, data)
    LiveView->>LiveView: assign(:pagination, pagination)
    LiveView->>User: Render page 1 (msg_001 visible, msg_060 not visible)
```

### 3.3. Pagination State Machine

```mermaid
stateDiagram-v2
    [*] --> Page1: Initial load (offset=0)
    Page1 --> Page2: next_page (offset=50)
    Page2 --> Page3: next_page (offset=100)
    Page3 --> Page2: prev_page (offset=50)
    Page2 --> Page1: prev_page (offset=0)
    Page1 --> Page1: prev_page disabled (offset=0)
    Page3 --> Page3: next_page disabled (has_more=false)
    
    note right of Page1
        offset = 0
        limit = 50
        has_more = true
    end note
    
    note right of Page2
        offset = 50
        limit = 50
        has_more = true
    end note
    
    note right of Page3
        offset = 100
        limit = 50
        has_more = false
    end note
```

## 4. Combined Flow: Filter + Pagination

```mermaid
sequenceDiagram
    participant User
    participant LiveView
    participant MessagesClient
    participant MockGateway

    Note over LiveView: Initial: status="all", offset=0
    User->>LiveView: Filter by status="completed"
    LiveView->>LiveView: handle_event("filter_status", %{"status" => "completed"})
    LiveView->>Router: push_patch(to: "/app/messages?status=completed")
    Router->>LiveView: handle_params(params, url, socket)
    LiveView->>LiveView: assign(:filter_status, "completed")
    LiveView->>LiveView: assign(:pagination, %{offset: 0})  # Reset to page 1
    LiveView->>LiveView: load_messages()
    LiveView->>MessagesClient: list_messages(status: "completed", offset: 0, limit: 50)
    MessagesClient->>MockGateway: GET /api/v1/messages?status=completed&offset=0&limit=50
    MockGateway-->>MessagesClient: 200 OK {data: [...], pagination: {total: 25, offset: 0, has_more: false}}
    MessagesClient-->>LiveView: {:ok, %{data: [...], pagination: {...}}}
    LiveView->>User: Render filtered messages (page 1, 25 total)
    
    Note over LiveView: User navigates to page 2
    User->>LiveView: Click "Next" button
    LiveView->>LiveView: handle_event("next_page", %{})
    LiveView->>LiveView: new_offset = 0 + 50 = 50
    LiveView->>LiveView: load_messages()
    LiveView->>MessagesClient: list_messages(status: "completed", offset: 50, limit: 50)
    MessagesClient->>MockGateway: GET /api/v1/messages?status=completed&offset=50&limit=50
    MockGateway-->>MessagesClient: 200 OK {data: [], pagination: {total: 25, offset: 50, has_more: false}}
    MessagesClient-->>LiveView: {:ok, %{data: [], pagination: {...}}}
    LiveView->>User: Render empty page (no more results)
```

## 5. Error Handling Flow

### 5.1. Gateway Error Flow

```mermaid
sequenceDiagram
    participant User
    participant LiveView
    participant MessagesClient
    participant MockGateway

    User->>LiveView: Trigger action (filter/delete/export)
    LiveView->>MessagesClient: API call
    MessagesClient->>MockGateway: HTTP request
    alt Gateway returns error
        MockGateway-->>MessagesClient: 500 Error {error: "forced_error"}
        MessagesClient->>MessagesClient: normalize_response({:error, ...})
        MessagesClient-->>LiveView: {:error, %{reason: :gateway_error, details: ...}}
        LiveView->>LiveView: GatewayErrorHelper.format_gateway_error(reason)
        LiveView->>LiveView: put_flash(:error, "Operation failed. ...")
        LiveView->>User: Render error flash (state preserved)
    else Gateway timeout
        MessagesClient-->>LiveView: {:error, :timeout}
        LiveView->>LiveView: put_flash(:error, "Request timed out")
        LiveView->>User: Render error flash
    end
```

## 6. State Transitions Summary

### 6.1. Filter State Transitions

| Event | From State | To State | Action |
|-------|-----------|----------|--------|
| `filter_status` | `{status: "all", ...}` | `{status: "completed", ...}` | `push_patch` → `handle_params` → `load_messages()` |
| `filter_type` | `{type: "all", ...}` | `{type: "chat", ...}` | `push_patch` → `handle_params` → `load_messages()` |
| `search` | `{search: "", ...}` | `{search: "query", ...}` | `push_patch` → `handle_params` → `load_messages()` |

### 6.2. Selection State Transitions

| Event | From State | To State | Action |
|-------|-----------|----------|--------|
| `toggle_select` | `selected_ids: MapSet.new()` | `selected_ids: MapSet.new(["msg_001"])` | Update assigns only |
| `select_all` | `selected_ids: MapSet.new()` | `selected_ids: MapSet.new([all_ids])` | Update assigns only |
| `deselect_all` | `selected_ids: MapSet.new([...])` | `selected_ids: MapSet.new()` | Update assigns only |
| `bulk_delete` (success) | `selected_ids: MapSet.new([...])` | `selected_ids: MapSet.new()` | Clear selection + reload messages |
| `bulk_delete` (error) | `selected_ids: MapSet.new([...])` | `selected_ids: MapSet.new([...])` | Preserve selection + show error |

### 6.3. Pagination State Transitions

| Event | From State | To State | Action |
|-------|-----------|----------|--------|
| `next_page` | `{offset: 0, limit: 50}` | `{offset: 50, limit: 50}` | Update pagination + `load_messages()` |
| `prev_page` | `{offset: 50, limit: 50}` | `{offset: 0, limit: 50}` | Update pagination + `load_messages()` |
| `filter_*` | `{offset: 50, ...}` | `{offset: 0, ...}` | Reset to page 1 + `load_messages()` |

## 7. Key Invariants

1. **Filter Invariant**: Changing filter always resets pagination to offset=0
2. **Selection Invariant**: Bulk actions preserve selection on error, clear on success
3. **Pagination Invariant**: `offset >= 0` and `offset % limit == 0` (always aligned to page boundaries)
4. **State Consistency**: All state changes trigger `load_messages()` to sync with backend
5. **Error Recovery**: Errors preserve current state (filters, selection, pagination) and show flash message

## 8. Testing Implications

### 8.1. Filter Tests
- Test that filter changes reset pagination
- Test that filter changes trigger `load_messages()`
- Test that URL params reflect filter state

### 8.2. Bulk Action Tests
- Test that selection state persists across renders
- Test that bulk_delete clears selection on success
- Test that bulk_delete preserves selection on error
- Test that export preserves selection

### 8.3. Pagination Tests
- Test that `next_page` increments offset by limit
- Test that `prev_page` decrements offset by limit (min 0)
- Test that pagination resets on filter change
- Test that disabled states work correctly (first/last page)

## References

- `apps/ui_web/lib/ui_web_web/live/messages_live/index.ex` - Implementation
- `apps/ui_web/test/ui_web_web/live/messages_live/index_test.exs` - Unit tests
- `apps/ui_web/test/support/mock_gateway.ex` - Mock Gateway implementation
- `apps/ui_web/docs/UI_WEB_TEST_STRATEGY.md` - Test strategy documentation

