# UI-Web Real-time Updates Guide

## Overview

UI-Web receives real-time updates from the backend via NATS, allowing LiveViews to update automatically without user refresh. This enables:

- **Live message list updates** - New messages appear automatically
- **Extension status changes** - Enable/disable actions reflect immediately
- **Status indicators** - Real-time health and processing status

**Technology Stack:**
- **NATS** - Message broker (Erlang Router publishes events)
- **Gnat** - Elixir NATS client
- **Phoenix.PubSub** - Internal pub/sub for LiveView communication
- **Phoenix LiveView** - UI layer that receives and renders updates

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────┐
│  NATS Subjects                                               │
│  beamline.extensions.events.*                                │
│  beamline.messages.events.*                                  │
│  beamline.policies.events.*                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  UiWeb.Realtime.EventSubscriber (GenServer)                 │
│  - Subscribes to NATS subjects                               │
│  - Decodes JSON messages                                     │
│  - Maps NATS topics → Phoenix topics                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Phoenix.PubSub                                              │
│  Topics:                                                     │
│  - "extensions:updates"                                      │
│  - "messages:updates"                                        │
│  - "policies:updates"                                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  LiveView (ExtensionsLive.Index, MessagesLive.Index)        │
│  - Subscribes to PubSub topic in mount/3                     │
│  - Receives {:event, event_data} in handle_info/2           │
│  - Updates socket.assigns                                    │
└─────────────────────────────────────────────────────────────┘
```

## EventSubscriber

**File:** `lib/ui_web/realtime/event_subscriber.ex`

### Responsibilities

1. **NATS Connection**
   - Connects to NATS server (configured via `NATS_URL`)
   - Uses `Gnat.ConnectionSupervisor` for connection management

2. **Subscription Management**
   - Subscribes to NATS subjects:
     - `beamline.extensions.events.>` - Extension events
     - `beamline.messages.events.>` - Message events
     - `beamline.policies.events.>` - Policy events

3. **Message Processing**
   - Receives NATS messages via `handle_info({:msg, %{topic: topic, body: body}}, state)`
   - Decodes JSON body using `Jason.decode/1`
   - Maps NATS topic to Phoenix PubSub topic:
     - `beamline.extensions.events.*` → `"extensions:updates"`
     - `beamline.messages.events.*` → `"messages:updates"`
     - `beamline.policies.events.*` → `"policies:updates"`

4. **Broadcasting**
   - Broadcasts decoded events to Phoenix PubSub:
     ```elixir
     Phoenix.PubSub.broadcast(UiWeb.PubSub, phoenix_topic, {:event, event})
     ```

### Important Notes

- **No UI logic** - EventSubscriber only bridges NATS → PubSub
- **Error handling** - Failed JSON decoding is logged but doesn't crash
- **Retry logic** - If NATS connection is not ready, retries subscription after 2 seconds

## LiveView Integration

### Subscription Pattern

**In `mount/3`:**
```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    # Subscribe to real-time updates
    Phoenix.PubSub.subscribe(UiWeb.PubSub, "messages:updates")
  end

  {:ok, socket}
end
```

**Important:** Only subscribe when `connected?(socket)` is true (not during initial render).

### Event Handling

**In `handle_info/2`:**
```elixir
def handle_info({:event, %{"type" => "message_created", "data" => message}}, socket) do
  # Add new message to list
  messages = [message | socket.assigns.messages]
  {:noreply, assign(socket, :messages, messages)}
end

def handle_info({:event, %{"type" => "message_updated", "data" => updated_message}}, socket) do
  # Update existing message in list
  messages = Enum.map(socket.assigns.messages, fn msg ->
    if msg["id"] == updated_message["id"] do
      updated_message
    else
      msg
    end
  end)
  {:noreply, assign(socket, :messages, messages)}
end

def handle_info({:event, %{"type" => "message_deleted", "data" => %{"id" => id}}}, socket) do
  # Remove message from list
  messages = Enum.reject(socket.assigns.messages, &(&1["id"] == id))
  {:noreply, assign(socket, :messages, messages)}
end

def handle_info({:event, _event}, socket) do
  # Ignore unknown event types
  {:noreply, socket}
end
```

### Example: ExtensionsLive.Index

**Full example:**
```elixir
defmodule UiWebWeb.ExtensionsLive.Index do
  use UiWebWeb, :live_view

  alias Phoenix.PubSub

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(UiWeb.PubSub, "extensions:updates")
    end

    {:ok, socket}
  end

  def handle_info({:event, %{"type" => "extension_created", "data" => extension}}, socket) do
    extensions = [extension | socket.assigns.extensions]
    {:noreply, assign(socket, :extensions, extensions)}
  end

  def handle_info({:event, %{"type" => "extension_updated", "data" => extension}}, socket) do
    extensions = Enum.map(socket.assigns.extensions, fn ext ->
      if ext["id"] == extension["id"] do
        extension
      else
        ext
      end
    end)
    {:noreply, assign(socket, :extensions, extensions)}
  end

  def handle_info({:event, %{"type" => "extension_deleted", "data" => %{"id" => id}}}, socket) do
    extensions = Enum.reject(socket.assigns.extensions, &(&1["id"] == id))
    {:noreply, assign(socket, :extensions, extensions)}
  end
end
```

## Event Schema

### Event Format

All events follow this JSON structure:

```json
{
  "type": "message_created",
  "data": {
    "id": "msg_123",
    "status": "completed",
    "content": { ... },
    ...
  }
}
```

### Registered Event Types

**Extensions:**
- `extension_created` - New extension registered
- `extension_updated` - Extension configuration changed
- `extension_deleted` - Extension removed

**Messages:**
- `message_created` - New message created
- `message_updated` - Message status/content updated
- `message_deleted` - Message deleted

**Policies:**
- `policy_created` - New policy created
- `policy_updated` - Policy configuration changed
- `policy_deleted` - Policy removed

### NATS Subject Mapping

| NATS Subject | Phoenix Topic | Event Types |
|--------------|---------------|-------------|
| `beamline.extensions.events.*` | `extensions:updates` | `extension_*` |
| `beamline.messages.events.*` | `messages:updates` | `message_*` |
| `beamline.policies.events.*` | `policies:updates` | `policy_*` |

**See also:**
- `docs/NATS_SUBJECTS.md` - Complete NATS subject registry
- `docs/ARCHITECTURE/PROTO_NATS_MAPPING.md` - Protocol to NATS mapping

## Feature Flags

### Enabling/Disabling Real-time

**Environment Variable:**
```bash
ENABLE_REAL_TIME=true   # Enable real-time (default)
ENABLE_REAL_TIME=false  # Disable real-time
```

**Configuration:**
```elixir
# config/runtime.exs
config :ui_web, :features,
  enable_real_time: System.get_env("ENABLE_REAL_TIME", "true") == "true"
```

### Behavior When Disabled

When `ENABLE_REAL_TIME=false`:

1. **EventSubscriber** starts but doesn't connect to NATS
2. **NATS connection** is not established
3. **UI works normally** - All HTTP operations via GatewayClient still work
4. **No real-time updates** - Users must refresh to see changes

**Use cases:**
- Local development without NATS
- Testing without real-time dependencies
- Debugging HTTP-only flows

## Telemetry & Observability

### Telemetry Events

**Event:** `[:ui_web, :nats, :event]`

**Measurements:**
- `duration` - Processing time in nanoseconds
- `size_bytes` - Message size in bytes

**Metadata:**
- `nats_topic` - Original NATS subject (e.g., `"beamline.messages.events.created"`)
- `phoenix_topic` - Phoenix PubSub topic (e.g., `"messages:updates"`)
- `event_type` - Event type from JSON (e.g., `"message_created"`)
- `result` - `:ok` or `:error` (for decode failures)

### Example Telemetry Handler

```elixir
:telemetry.attach(
  "nats-event-handler",
  [:ui_web, :nats, :event],
  fn _event, measurements, metadata, _config ->
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    
    Logger.info("NATS event",
      event_type: metadata.event_type,
      nats_topic: metadata.nats_topic,
      duration_ms: duration_ms,
      size_bytes: measurements.size_bytes
    )
  end,
  %{}
)
```

### Using in Grafana/Logs

Telemetry events can be exported to:
- **Prometheus** - Via `:telemetry_poller` and custom exporter
- **OpenTelemetry** - Via `opentelemetry` library
- **Structured logs** - Via `UiWeb.TelemetryLogger` (already configured)

**See also:**
- `lib/ui_web/telemetry_logger.ex` - Telemetry logger implementation

## Testing Strategy

### Testing Without NATS

**Option 1: Direct handle_info call**
```elixir
defmodule UiWebWeb.MessagesLive.IndexTest do
  use ExUnit.Case
  import Phoenix.LiveViewTest

  test "updates message list on real-time event" do
    {:ok, view, _html} = live(conn, "/app/messages")

    # Simulate NATS event by calling handle_info directly
    send(view.pid, {:event, %{
      "type" => "message_created",
      "data" => %{"id" => "msg_123", "status" => "pending"}
    }})

    assert render(view) =~ "msg_123"
  end
end
```

**Option 2: Mock EventSubscriber**
```elixir
# In test_helper.exs or test setup
defmodule MockEventSubscriber do
  def broadcast_event(topic, event) do
    Phoenix.PubSub.broadcast(UiWeb.PubSub, topic, {:event, event})
  end
end
```

### Integration Testing

**E2E test with real NATS (optional):**
```elixir
defmodule UiWeb.Integration.RealtimeTest do
  use ExUnit.Case

  test "message appears in UI after NATS event" do
    # 1. Start UI-Web
    # 2. Publish message to NATS
    Gnat.pub(:gnat, "beamline.messages.events.created", Jason.encode!(%{
      "type" => "message_created",
      "data" => %{"id" => "msg_123"}
    }))
    
    # 3. Wait for UI update
    # 4. Assert message appears in UI
  end
end
```

**Note:** Integration tests with real NATS are optional and typically run in CI/CD only.

## Gotchas / Best Practices

### ❌ Don't Create NATS Clients in LiveView

**Bad:**
```elixir
def mount(_params, _session, socket) do
  # Direct NATS subscription in LiveView - wrong!
  Gnat.sub(:gnat, self(), "beamline.messages.events.>")
  {:ok, socket}
end
```

**Good:**
```elixir
def mount(_params, _session, socket) do
  # Subscribe to Phoenix PubSub - correct!
  Phoenix.PubSub.subscribe(UiWeb.PubSub, "messages:updates")
  {:ok, socket}
end
```

### ✅ Keep PubSub Topics Separate

**Bad:**
```elixir
# Mixing concerns
Phoenix.PubSub.subscribe(UiWeb.PubSub, "all:updates")  # Too generic
```

**Good:**
```elixir
# Specific topics
Phoenix.PubSub.subscribe(UiWeb.PubSub, "messages:updates")
Phoenix.PubSub.subscribe(UiWeb.PubSub, "extensions:updates")
```

### ✅ Limit Payload Size

**Bad:**
```json
{
  "type": "message_created",
  "data": {
    "id": "msg_123",
    "content": { /* 10MB of data */ }
  }
}
```

**Good:**
```json
{
  "type": "message_created",
  "data": {
    "id": "msg_123",
    "status": "completed"
  }
}
```

**Pattern:** Send minimal data in events, fetch full data via GatewayClient if needed.

### ✅ Handle Unknown Event Types

```elixir
def handle_info({:event, %{"type" => unknown_type}}, socket) do
  # Log but don't crash
  require Logger
  Logger.warning("Unknown event type: #{unknown_type}")
  {:noreply, socket}
end
```

### ✅ Pattern Match on Event Type

```elixir
# Good: Specific pattern matching
def handle_info({:event, %{"type" => "message_created", "data" => message}}, socket) do
  # Handle creation
end

def handle_info({:event, %{"type" => "message_updated", "data" => message}}, socket) do
  # Handle update
end

# Bad: Generic handler that checks type inside
def handle_info({:event, event}, socket) do
  case event["type"] do
    "message_created" -> # ...
    "message_updated" -> # ...
  end
end
```

## Troubleshooting

### Events Not Arriving

1. **Check NATS connection:**
   ```elixir
   Process.whereis(:gnat)  # Should return PID, not nil
   ```

2. **Check EventSubscriber status:**
   ```elixir
   :sys.get_state(UiWeb.Realtime.EventSubscriber)
   ```

3. **Check PubSub subscription:**
   ```elixir
   # In LiveView, verify subscription
   Phoenix.PubSub.list(UiWeb.PubSub, "messages:updates")
   ```

4. **Check logs:**
   - EventSubscriber logs subscription status
   - Telemetry events show event processing

### Events Arriving But UI Not Updating

1. **Verify handle_info pattern matching:**
   - Event structure must match pattern exactly
   - Check event type string matches

2. **Check socket assigns:**
   - Verify assigns are updated in handle_info
   - Check if template re-renders on assign change

3. **Verify LiveView is connected:**
   - Real-time only works when `connected?(socket)` is true
   - Initial render doesn't receive events

## Related Documentation

- **`docs/UI_WEB_GATEWAY_INTEGRATION.md`** - HTTP integration with C-Gateway
- **`docs/NATS_SUBJECTS.md`** - NATS subject registry
- **`docs/ARCHITECTURE/PROTO_NATS_MAPPING.md`** - Protocol to NATS mapping
- **`lib/ui_web/realtime/event_subscriber.ex`** - EventSubscriber source code
- **`lib/ui_web/telemetry_logger.ex`** - Telemetry logger implementation

