# UI-Web ↔ C-Gateway API Contracts

This document defines the API contracts between UI-Web (Phoenix LiveView) and C-Gateway (C11 HTTP Gateway).

## Related Documentation

- **[UI_WEB_GATEWAY_INTEGRATION.md](./UI_WEB_GATEWAY_INTEGRATION.md)** - Complete guide to GatewayClient and HTTP integration
- **[UI_WEB_REALTIME.md](./UI_WEB_REALTIME.md)** - Real-time updates via NATS and Phoenix PubSub
- **[UI_WEB_TEST_STRATEGY.md](./UI_WEB_TEST_STRATEGY.md)** - Testing strategy for LiveView, mocks, and helpers

## Base URL

- **Development**: `http://localhost:8080`
- **Test**: `http://localhost:8081` (Mock Gateway)
- **Production**: `https://gateway.beamline.io` (configurable)

## Endpoints

### GET /health

**Description**: Health check endpoint for Gateway status.

**Response**: `200 OK`

```json
{
  "status": "ok" | "degraded" | "unhealthy",
  "nats": {
    "connected": boolean
  },
  "timestamp_ms": integer
}
```

**Example**:
```json
{
  "status": "ok",
  "nats": {
    "connected": true
  },
  "timestamp_ms": 1704067200000
}
```

---

### GET /_health

**Description**: Alternative health endpoint (fallback).

**Response**: Same as `/health`

---

### GET /metrics

**Description**: Aggregated metrics from Gateway.

**Response**: `200 OK`

```json
{
  "rps": number | null,
  "latency": {
    "p50": number,
    "p95": number,
    "p99": number
  },
  "error_rate": number | null
}
```

**Example**:
```json
{
  "rps": 100,
  "latency": {
    "p50": 10,
    "p95": 50,
    "p99": 100
  },
  "error_rate": 0.01
}
```

**Note**: Gateway may return Prometheus text format. UI-Web parses it to JSON.

---

### POST /api/v1/messages

**Description**: Create a new message for routing.

**Request**:
```json
{
  "tenant_id": string (required),
  "message_type": string (required),
  "payload": string (required, JSON-encoded),
  "trace_id": string (optional)
}
```

**Response**: `200 OK`

```json
{
  "message_id": string,
  "ack_timestamp_ms": integer,
  "status": "published" | "queued" | "rejected"
}
```

**Example Request**:
```json
{
  "tenant_id": "tenant_abc123",
  "message_type": "chat",
  "payload": "{\"text\": \"Hello, world!\"}",
  "trace_id": "trace_xyz789"
}
```

**Example Response**:
```json
{
  "message_id": "msg_1704067200000",
  "ack_timestamp_ms": 1704067200000,
  "status": "published"
}
```

**Error Responses**:
- `400 Bad Request`: Invalid request body or missing required fields
- `422 Unprocessable Entity`: Validation errors

---

### GET /api/v1/messages

**Description**: List messages with pagination and filtering.

**Query Parameters**:
- `tenant_id`: string (optional) - Filter by tenant
- `status`: string (optional) - Filter by status
- `page`: integer (optional, default: 1) - Page number
- `limit`: integer (optional, default: 20) - Items per page

**Response**: `200 OK`

```json
{
  "items": [Message],
  "total": integer,
  "page": integer
}
```

**Message Schema**:
```json
{
  "message_id": string,
  "tenant_id": string,
  "message_type": string,
  "payload": string,
  "status": string,
  "created_at": integer,
  "trace_id": string | null
}
```

**Example**:
```json
{
  "items": [
    {
      "message_id": "msg_1704067200000",
      "tenant_id": "tenant_abc123",
      "message_type": "chat",
      "payload": "{\"text\": \"Hello\"}",
      "status": "completed",
      "created_at": 1704067200000,
      "trace_id": "trace_xyz789"
    }
  ],
  "total": 1,
  "page": 1
}
```

---

### GET /api/v1/messages/:id

**Description**: Get message details by ID.

**Response**: `200 OK`

```json
{
  "message_id": string,
  "tenant_id": string,
  "message_type": string,
  "payload": string,
  "status": string,
  "created_at": integer,
  "trace_id": string | null
}
```

**Error Responses**:
- `404 Not Found`: Message not found

---

### DELETE /api/v1/messages/:id

**Description**: Delete a message by ID.

**Response**: `204 No Content` (success) or `404 Not Found` (message not found)

---

## Error Handling

All endpoints may return error responses:

**Error Response Format**:
```json
{
  "error": string,
  "message": string (optional),
  "details": object (optional)
}
```

**HTTP Status Codes**:
- `200 OK`: Success
- `204 No Content`: Success (DELETE)
- `400 Bad Request`: Invalid request
- `404 Not Found`: Resource not found
- `422 Unprocessable Entity`: Validation error
- `500 Internal Server Error`: Server error

---

## Contract Testing

Contract tests are located in:
- `test/ui_web/integration/gateway_contract_test.exs`

These tests validate:
- Response schemas match expected format
- Required fields are present
- Optional fields are handled correctly
- Error responses follow contract

---

## Mock Gateway

For testing, a Mock Gateway is available:
- **Location**: `test/support/mock_gateway.ex`
- **Port**: `8081` (configurable)
- **Auto-started**: In `test_helper.exs`

**Usage**:
```elixir
# Mock Gateway automatically starts in tests
# Use GATEWAY_URL=http://localhost:8081 for integration tests
```

---

## Versioning

Current API version: **v1**

Future versions will be added as:
- `/api/v2/messages` (when breaking changes are needed)

---

## References

- C-Gateway implementation: `apps/c-gateway/`
- GatewayClient: `lib/ui_web/services/gateway_client.ex`
- Contract tests: `test/ui_web/integration/gateway_contract_test.exs`
- Schema validators: `test/support/schema_validators.ex`

## Related Documentation

- **[UI_WEB_GATEWAY_INTEGRATION.md](./UI_WEB_GATEWAY_INTEGRATION.md)** - Complete guide to GatewayClient and HTTP integration
- **[UI_WEB_REALTIME.md](./UI_WEB_REALTIME.md)** - Real-time updates via NATS and Phoenix PubSub

