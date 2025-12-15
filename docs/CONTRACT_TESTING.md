# Contract Testing: Mock Gateway as API Specification

## Purpose

This document describes how Mock Gateway serves as a **living specification** for the C-Gateway backend API. The Mock Gateway implementation defines the contract between UI-Web and the backend, ensuring consistency and enabling contract testing.

---

## Overview

### The Problem

- UI-Web needs to know the exact API contract from C-Gateway
- Backend changes can break UI without clear contract definition
- Mock Gateway and real Gateway can drift apart over time
- No automated way to verify contract compliance

### The Solution

**Mock Gateway as Source of Truth**:
1. Mock Gateway implements the API contract
2. `ApiSpec` module extracts specification from Mock Gateway
3. Contract tests validate Mock Gateway matches specification
4. Optional: Compare Mock Gateway with real Gateway in staging

---

## Architecture

```
┌─────────────────┐
│   ApiSpec       │  ← Extracts specification from Mock Gateway
│   (Spec)        │
└────────┬────────┘
         │
         ├─────────────────┐
         │                 │
┌────────▼────────┐  ┌─────▼──────────┐
│ Mock Gateway    │  │ Real Gateway   │
│ (Test)          │  │ (Production)   │
└─────────────────┘  └────────────────┘
         │
         │
┌────────▼────────┐
│ Contract Tests  │  ← Validates Mock matches Spec
└─────────────────┘
```

---

## Components

### 1. ApiSpec Module

**Location**: `lib/ui_web/contracts/api_spec.ex`

**Purpose**: Defines the API contract specification extracted from Mock Gateway.

**Key Functions**:
- `endpoints/0` - Returns all endpoint specifications
- `to_json_schema/0` - Exports specification as JSON Schema

**Example**:
```elixir
spec = ApiSpec.endpoints()["GET /api/v1/messages"]
# => %{
#   method: "GET",
#   path: "/api/v1/messages",
#   request: %{query_params: %{...}},
#   response: %{success: %{status: 200, schema: %{...}}}
# }
```

### 2. ContractValidator Module

**Location**: `lib/ui_web/contracts/contract_validator.ex`

**Purpose**: Validates that Mock Gateway responses match the specification.

**Key Functions**:
- `validate_endpoint/2` - Validate single endpoint response
- `validate_all/0` - Validate all endpoints
- `compare_with_real_gateway/2` - Compare Mock with real Gateway (optional)

**Example**:
```elixir
response = %{status: 200, body: %{"data" => [], "pagination" => %{}}}
ContractValidator.validate_endpoint("GET /api/v1/messages", response)
# => {:ok, :valid}
```

### 3. Mock Gateway

**Location**: `test/support/mock_gateway.ex`

**Purpose**: Implements the API contract for testing.

**Key Rules**:
- All endpoints must match `ApiSpec` definitions
- Response formats must match specification schemas
- Error responses must match specification error formats

---

## Using ApiSpec

### Getting Endpoint Specification

```elixir
# Get all endpoints
endpoints = ApiSpec.endpoints()

# Get specific endpoint
messages_spec = ApiSpec.endpoints()["GET /api/v1/messages"]

# Access request parameters
query_params = messages_spec.request.query_params
# => %{"status" => "string (optional)", "limit" => "integer (optional)", ...}

# Access response schema
response_schema = messages_spec.response.success.schema
# => %{"data" => "array of message objects", "pagination" => %{...}}
```

### Exporting to JSON Schema

```elixir
json_schema = ApiSpec.to_json_schema()
# => %{
#   "GET /api/v1/messages" => %{
#     "method" => "GET",
#     "path" => "/api/v1/messages",
#     "request" => %{...},
#     "response" => %{...}
#   },
#   ...
# }
```

---

## Contract Testing

### Validating Mock Gateway Responses

```elixir
# In a test
test "messages list endpoint matches spec" do
  # Make request to Mock Gateway
  {:ok, response} = GatewayClient.get_json("/api/v1/messages")
  
  # Validate against specification
  result = ContractValidator.validate_endpoint(
    "GET /api/v1/messages",
    %{status: 200, body: response}
  )
  
  assert {:ok, :valid} = result
end
```

### Validating All Endpoints

```elixir
test "all Mock Gateway endpoints match spec" do
  results = ContractValidator.validate_all()
  
  # Check that all endpoints are valid
  Enum.each(results, fn {_endpoint, result} ->
    assert {:ok, _} = result
  end)
end
```

### Comparing with Real Gateway (Optional)

```elixir
# Only runs if real Gateway is available (not in test environment)
test "Mock Gateway matches real Gateway" do
  result = ContractValidator.compare_with_real_gateway(
    "GET /api/v1/messages",
    []
  )
  
  case result do
    {:ok, :match} -> :ok
    {:skip, _} -> :ok  # Skipped in test environment
    {:error, reason} -> flunk("Contract mismatch: #{inspect(reason)}")
  end
end
```

---

## Adding New Endpoints

### Step 1: Add to Mock Gateway

In `test/support/mock_gateway.ex`:

```elixir
get "/api/v1/your_resource" do
  query = conn.query_params
  
  case Map.get(query, "status") do
    "force_error" ->
      json_response(conn, 500, %{"error" => "forced_error"})
    _ ->
      json_response(conn, 200, %{
        data: mock_data,
        pagination: %{total: length(mock_data), limit: 20, offset: 0}
      })
  end
end
```

### Step 2: Add to ApiSpec

In `lib/ui_web/contracts/api_spec.ex`:

```elixir
def endpoints do
  %{
    # ... existing endpoints ...
    "GET /api/v1/your_resource" => your_resource_list_spec(),
  }
end

defp your_resource_list_spec do
  %{
    method: "GET",
    path: "/api/v1/your_resource",
    description: "List your resources with filters",
    request: %{
      query_params: %{
        "status" => "string (optional)",
        "limit" => "integer (optional, default: 20)",
        "offset" => "integer (optional, default: 0)"
      }
    },
    response: %{
      success: %{
        status: 200,
        schema: %{
          "data" => "array of resource objects",
          "pagination" => %{
            "total" => "integer",
            "limit" => "integer",
            "offset" => "integer",
            "has_more" => "boolean"
          }
        }
      },
      errors: [
        %{status: 500, body: %{"error" => "string"}}
      ]
    }
  }
end
```

### Step 3: Add Contract Test

In `test/ui_web/contracts/contract_validator_test.exs`:

```elixir
test "your_resource endpoint matches spec" do
  # Test Mock Gateway response matches spec
  {:ok, response} = GatewayClient.get_json("/api/v1/your_resource")
  
  result = ContractValidator.validate_endpoint(
    "GET /api/v1/your_resource",
    %{status: 200, body: response}
  )
  
  assert {:ok, :valid} = result
end
```

---

## Best Practices

### 1. Keep Spec and Mock in Sync

- **Always update `ApiSpec`** when adding/modifying Mock Gateway endpoints
- **Run contract tests** to verify Mock Gateway matches spec
- **Document breaking changes** in spec description

### 2. Use Consistent Response Formats

- **Success responses**: Always include `data` or `items` array
- **Pagination**: Use consistent `pagination` object structure
- **Errors**: Use consistent error format: `%{"error" => "string"}`

### 3. Version Your API

- **Add version to path**: `/api/v1/...`
- **Document version changes** in spec description
- **Support multiple versions** if needed

### 4. Test Contract Compliance

- **Run contract tests** in CI/CD pipeline
- **Validate Mock Gateway** matches spec on every change
- **Compare with real Gateway** in staging environment (optional)

---

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Run Contract Tests
  run: |
    mix test test/ui_web/contracts/
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

mix test test/ui_web/contracts/
if [ $? -ne 0 ]; then
  echo "Contract tests failed. Please ensure Mock Gateway matches ApiSpec."
  exit 1
fi
```

---

## Benefits

1. **Single Source of Truth**: Mock Gateway defines the contract
2. **Automated Validation**: Contract tests catch drift early
3. **Documentation**: ApiSpec serves as API documentation
4. **Backend Alignment**: Real Gateway can be compared with Mock
5. **Breaking Change Detection**: Contract tests fail on breaking changes

---

## Future Enhancements

1. **OpenAPI/Swagger Export**: Generate OpenAPI spec from ApiSpec
2. **Automatic Mock Generation**: Generate Mock Gateway from OpenAPI spec
3. **Backend Integration**: Real Gateway validates against ApiSpec
4. **Versioning Support**: Track API versions in spec
5. **Schema Validation**: Use JSON Schema for strict validation

---

## References

- **[UI_WEB_TEST_STRATEGY.md](./UI_WEB_TEST_STRATEGY.md)** - Testing strategy
- **[UI_WEB_GATEWAY_INTEGRATION.md](./UI_WEB_GATEWAY_INTEGRATION.md)** - Gateway integration
- `lib/ui_web/contracts/api_spec.ex` - API specification module
- `lib/ui_web/contracts/contract_validator.ex` - Contract validator
- `test/support/mock_gateway.ex` - Mock Gateway implementation

---

*Last updated: 2025-01-27*
*Based on: Mock Gateway implementation and contract testing patterns*

