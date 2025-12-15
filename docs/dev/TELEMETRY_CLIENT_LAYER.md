# Telemetry & Structured Logging in Client Layer

**Status:** ✅ **COMPLETE**

Standardized Telemetry events and structured logging for **LiveView → Clients → GatewayClient → Gateway → Backend** flow.

---

## 🎯 Goal

Answer questions:
- **"What is UI doing with Gateway right now?"**
- **"Why is this screen slow?"**
- **"How many times does MessagesLive call /messages? With what filters?"**
- **"What errors come from Gateway, and on which LiveView actions?"**

---

## 📊 Event Schema

### Client Layer Events

#### `[:ui_web, :client, :request]`

**Emitted:** Before Gateway request is sent.

**Metadata:**
```elixir
%{
  client: :messages | :extensions | :policies | :dashboard,
  operation: :list | :get | :create | :update | :delete | :export | :bulk_delete | :toggle,
  method: :get | :post | :put | :patch | :delete,
  url: "/api/v1/messages",
  query: %{status: "completed", limit: 20},
  tenant_id: "tenant_dev" | nil,
  user_id: "test_user" | nil,
  request_id: "..." | nil  # From Logger.metadata()[:request_id]
}
```

#### `[:ui_web, :client, :response]`

**Emitted:** After Gateway response is received.

**Measurements:**
```elixir
%{
  duration: native_time_diff  # Convert to ms in handler
}
```

**Metadata:**
```elixir
%{
  # All fields from :request event, plus:
  status: 200 | 204 | 400 | 500,
  success: true | false,
  error_reason: nil | :gateway_error | :decode_error | :timeout | :unknown_error
}
```

### LiveView Action Events

#### `[:ui_web, :live, :action]`

**Emitted:** When LiveView performs domain action (bulk_delete, export, toggle_extension).

**Metadata:**
```elixir
%{
  liveview: UiWebWeb.MessagesLive.Index,
  event: "bulk_delete" | "export" | "delete" | "toggle_extension" | "delete_extension",
  tenant_id: "tenant_dev" | nil,
  user_id: "test_user" | nil,
  request_id: "..." | nil,
  # Action-specific fields:
  selection_count: 5,  # for bulk_delete
  format: "json",      # for export
  message_id: "msg_001",  # for delete
  extension_id: "ext_001"  # for toggle/delete extension
}
```

---

## 🔧 Implementation

### 1. GatewayClient Instrumentation

**File:** `apps/ui_web/lib/ui_web/services/gateway_client.ex`

**Changes:**
- `request/4` now emits `[:ui_web, :client, :request]` before request
- `request/4` now emits `[:ui_web, :client, :response]` after response
- Extracts `client`, `operation`, `tenant_id`, `user_id`, `request_id` from opts
- `get_json`, `post_json`, `put_json`, `delete` auto-infer `operation` from path using `infer_operation/2` helper
- `infer_operation/2` deduces operation from HTTP method and path (e.g., `GET /api/v1/messages` → `:list`, `POST /api/v1/messages/export` → `:export`)

**Example:**
```elixir
# Explicit operation (recommended for clarity)
GatewayClient.get_json("/api/v1/messages", 
  client: :messages,
  operation: :list,
  tenant_id: "tenant_dev",
  user_id: "user_123",
  params: %{status: "completed"}
)

# Auto-inferred operation (fallback if not provided)
GatewayClient.get_json("/api/v1/messages", 
  client: :messages,
  tenant_id: "tenant_dev",
  user_id: "user_123",
  params: %{status: "completed"}
)
# → operation will be auto-inferred as :list from path
```

---

### 2. Client Updates (MessagesClient, ExtensionsClient)

**Files:**
- `apps/ui_web/lib/ui_web/services/messages_client.ex`
- `apps/ui_web/lib/ui_web/services/extensions_client.ex`

**Changes:**
- All methods accept `opts` keyword list with `:tenant_id`, `:user_id`, `:request_id`
- `extract_client_opts/1` helper extracts Telemetry context
- Methods pass `client: :messages` or `client: :extensions` to GatewayClient
- Methods pass `operation: :list | :get | :delete | :export | :bulk_delete` to GatewayClient

**Example:**
```elixir
# In MessagesLive.Index
context = LiveViewHelpers.get_context(socket)
MessagesClient.list_messages([status: "completed"] ++ context)
```

---

### 3. LiveView Action Events

**Files:**
- `apps/ui_web/lib/ui_web/telemetry/liveview_helpers.ex` (NEW)
- `apps/ui_web/lib/ui_web_web/live/messages_live/index.ex`
- `apps/ui_web/lib/ui_web_web/live/extensions_live/index.ex`

**Changes:**
- `LiveViewHelpers.emit_action/3` emits `[:ui_web, :live, :action]` events
- `LiveViewHelpers.get_context/1` extracts `tenant_id`, `user_id`, `request_id` from socket
- Added action events in `handle_event("bulk_delete")`, `handle_event("export")`, `handle_event("delete")`
- Added action events in `handle_event("toggle_extension")`, `handle_event("delete_extension")`

**Example:**
```elixir
def handle_event("bulk_delete", _params, socket) do
  # Emit action event
  LiveViewHelpers.emit_action(socket, "bulk_delete", %{
    selection_count: length(ids)
  })
  
  # Call client with context
  context = LiveViewHelpers.get_context(socket)
  MessagesClient.bulk_delete_messages(ids, context)
end
```

---

### 4. TelemetryLogger Updates

**File:** `apps/ui_web/lib/ui_web/telemetry_logger.ex`

**Changes:**
- Added handlers for `[:ui_web, :client, :request]`
- Added handlers for `[:ui_web, :client, :response]`
- Added handlers for `[:ui_web, :live, :action]`
- Structured logging with all metadata fields

**Log Format:**
```elixir
Logger.info("client_request",
  client: :messages,
  operation: :list,
  method: :get,
  url: "/api/v1/messages",
  query: %{status: "completed"},
  tenant_id: "tenant_dev",
  user_id: "user_123",
  request_id: "..."
)

Logger.info("client_response",
  client: :messages,
  operation: :list,
  method: :get,
  url: "/api/v1/messages",
  status: 200,
  success: true,
  error_reason: nil,
  duration_ms: 12.3,
  tenant_id: "tenant_dev",
  user_id: "user_123",
  request_id: "..."
)

Logger.info("liveview_action",
  liveview: UiWebWeb.MessagesLive.Index,
  event: "bulk_delete",
  tenant_id: "tenant_dev",
  user_id: "user_123",
  request_id: "..."
)
```

---

## 📋 Event Flow Example

### Complete Flow: Bulk Delete

```
1. User clicks "Delete Selected" in MessagesLive.Index
   ↓
2. handle_event("bulk_delete", ...)
   ↓
3. :telemetry.execute([:ui_web, :live, :action], %{}, %{
     liveview: UiWebWeb.MessagesLive.Index,
     event: "bulk_delete",
     selection_count: 5,
     tenant_id: "tenant_dev",
     user_id: "user_123"
   })
   ↓
4. MessagesClient.bulk_delete_messages(ids, [tenant_id: "tenant_dev", user_id: "user_123"])
   ↓
5. GatewayClient.post_json("/api/v1/messages/bulk_delete", body, [
     client: :messages,
     operation: :bulk_delete,
     tenant_id: "tenant_dev",
     user_id: "user_123"
   ])
   ↓
6. :telemetry.execute([:ui_web, :client, :request], %{}, %{
     client: :messages,
     operation: :bulk_delete,
     method: :post,
     url: "/api/v1/messages/bulk_delete",
     tenant_id: "tenant_dev",
     user_id: "user_123"
   })
   ↓
7. HTTP request to Gateway
   ↓
8. Gateway responds with 200 OK
   ↓
9. :telemetry.execute([:ui_web, :client, :response], %{duration: 15000}, %{
     client: :messages,
     operation: :bulk_delete,
     method: :post,
     url: "/api/v1/messages/bulk_delete",
     status: 200,
     success: true,
     error_reason: nil,
     duration_ms: 15.0,
     tenant_id: "tenant_dev",
     user_id: "user_123"
   })
```

**In logs, you see:**
```
[info] liveview_action liveview=UiWebWeb.MessagesLive.Index event=bulk_delete selection_count=5 tenant_id=tenant_dev user_id=user_123
[info] client_request client=messages operation=bulk_delete method=post url=/api/v1/messages/bulk_delete tenant_id=tenant_dev user_id=user_123
[info] client_response client=messages operation=bulk_delete method=post url=/api/v1/messages/bulk_delete status=200 success=true duration_ms=15.0 tenant_id=tenant_dev user_id=user_123
```

---

## 🔍 Using Telemetry for Debugging

### Question: "Why is MessagesLive slow?"

**Answer:**
```bash
# Filter logs for client_response events from MessagesLive
grep "client_response.*client=messages" logs/prod.log | \
  awk '{print $NF}' | \
  sort -n | \
  tail -10

# Find slow operations
grep "client_response.*duration_ms" logs/prod.log | \
  awk -F'duration_ms=' '{print $2}' | \
  awk '{if ($1 > 1000) print $0}'
```

### Question: "How many times does MessagesLive call /messages?"

**Answer:**
```bash
# Count client_request events for list operation
grep "client_request.*operation=list.*client=messages" logs/prod.log | wc -l

# Group by query params
grep "client_request.*operation=list.*client=messages" logs/prod.log | \
  grep -o 'query={[^}]*}' | \
  sort | uniq -c
```

### Question: "What errors come from Gateway on bulk_delete?"

**Answer:**
```bash
# Find failed bulk_delete operations
grep "client_response.*operation=bulk_delete.*success=false" logs/prod.log

# Find error reasons
grep "client_response.*operation=bulk_delete" logs/prod.log | \
  grep -o 'error_reason=[^ ]*' | \
  sort | uniq -c
```

### Question: "Which LiveView actions trigger Gateway calls?"

**Answer:**
```bash
# Find action → request correlation
# Look for liveview_action followed by client_request with same request_id
grep -E "(liveview_action|client_request)" logs/prod.log | \
  grep -A1 "liveview_action" | \
  grep "client_request"
```

---

## 📚 Files Changed

### Core Implementation

1. **`apps/ui_web/lib/ui_web/services/gateway_client.ex`**
   - Added `[:ui_web, :client, :request]` and `[:ui_web, :client, :response]` events
   - Added `infer_operation/2` helper to deduce operation from method and path
   - Updated `get_json`, `post_json`, `put_json`, `delete` to auto-infer operation if not provided
   - Operation inference rules:
     - `GET /api/v1/messages` → `:list`
     - `GET /api/v1/messages/:id` → `:get`
     - `POST /api/v1/messages/export` → `:export`
     - `POST /api/v1/messages/bulk_delete` → `:bulk_delete`
     - `PATCH /api/v1/extensions/:id` (with `/toggle`) → `:toggle`
     - `DELETE /api/v1/messages/:id` → `:delete`

2. **`apps/ui_web/lib/ui_web/services/messages_client.ex`**
   - Added `extract_client_opts/1` helper
   - Updated all methods to accept and pass Telemetry context
   - Methods now pass `client: :messages` and `operation: :list | :get | :delete | :export | :bulk_delete`

3. **`apps/ui_web/lib/ui_web/services/extensions_client.ex`**
   - Added `extract_client_opts/1` helper
   - Updated all methods to accept and pass Telemetry context
   - Methods now pass `client: :extensions` and `operation: :list | :toggle | :delete`

4. **`apps/ui_web/lib/ui_web/telemetry/liveview_helpers.ex`** (NEW)
   - `emit_action/3` - Emit LiveView action events
   - `get_context/1` - Extract tenant_id, user_id, request_id from socket

5. **`apps/ui_web/lib/ui_web/telemetry_logger.ex`**
   - Added handlers for `[:ui_web, :client, :request]`
   - Added handlers for `[:ui_web, :client, :response]`
   - Added handlers for `[:ui_web, :live, :action]`

### LiveView Updates

6. **`apps/ui_web/lib/ui_web_web/live/messages_live/index.ex`**
   - Added `LiveViewHelpers` alias
   - Added action events in `handle_event("bulk_delete")`, `handle_event("export")`, `handle_event("delete")`
   - Updated `load_messages/1` to pass context to `MessagesClient.list_messages/1`

7. **`apps/ui_web/lib/ui_web_web/live/extensions_live/index.ex`**
   - Added `LiveViewHelpers` alias
   - Added action events in `handle_event("toggle_extension")`, `handle_event("delete_extension")`
   - Updated `load_extensions/1` to pass context to `ExtensionsClient.list_extensions/1`

---

## ✅ Acceptance Criteria

1. ✅ **Event schema defined** for `[:ui_web, :client, :request]`, `[:ui_web, :client, :response]`, `[:ui_web, :live, :action]`
2. ✅ **GatewayClient instrumented** with Telemetry events
3. ✅ **MessagesClient and ExtensionsClient updated** to pass context
4. ✅ **LiveView action events added** in key `handle_event` functions
5. ✅ **TelemetryLogger updated** to log all new events
6. ✅ **Documentation created** with examples and usage

---

## 🚀 Next Steps (Optional)

### OpenTelemetry Tracing

Add distributed tracing:

```elixir
# In TelemetryLogger
def handle_event([:ui_web, :client, :request], _measurements, metadata, _config) do
  span = :otel_tracer.start_span("ui.client.request", 
    attributes: [
      {"client", to_string(metadata.client)},
      {"operation", to_string(metadata.operation)},
      {"method", to_string(metadata.method)},
      {"url", metadata.url}
    ]
  )
  
  # Store span in process dictionary
  Process.put(:client_span, span)
end

def handle_event([:ui_web, :client, :response], measurements, metadata, _config) do
  if span = Process.get(:client_span) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    :otel_span.set_attribute(span, "duration_ms", duration_ms)
    :otel_span.set_attribute(span, "status", metadata.status)
    :otel_span.set_status(span, if(metadata.success, do: :ok, else: :error))
    :otel_tracer.end_span(span)
    Process.delete(:client_span)
  end
end
```

### Prometheus Metrics

Add metrics export:

```elixir
# In TelemetryLogger
def handle_event([:ui_web, :client, :response], measurements, metadata, _config) do
  duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
  
  :telemetry.execute(
    [:ui_web, :client, :response, :duration],
    %{duration: duration_ms},
    %{
      client: metadata.client,
      operation: metadata.operation,
      status: metadata.status,
      success: metadata.success
    }
  )
end
```

---

## 📖 References

- **Telemetry Events:** `apps/ui_web/lib/ui_web/telemetry_logger.ex`
- **LiveView Helpers:** `apps/ui_web/lib/ui_web/telemetry/liveview_helpers.ex`
- **GatewayClient:** `apps/ui_web/lib/ui_web/services/gateway_client.ex`
- **MessagesClient:** `apps/ui_web/lib/ui_web/services/messages_client.ex`
- **ExtensionsClient:** `apps/ui_web/lib/ui_web/services/extensions_client.ex`

