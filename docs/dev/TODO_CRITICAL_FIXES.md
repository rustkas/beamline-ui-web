# UI-Web Critical Fixes TODO List

**Created**: 2025-11-22  
**Status**: In Progress  
**Priority**: P0 (Blocking for CP4-UI)

---

## 📋 Tasks Overview

- [x] **Task 1**: Fix Compilation Warnings (30 min) - P0 ✅ DONE
- [x] **Task 2**: Migrate GatewayClient to Req (2 hours) - P0 ✅ DONE
- [x] **Task 3**: Fix API Endpoints (1 hour) - P0 ✅ DONE
- [x] **Task 4**: Enforce Authentication on /app/* (2 hours) - P0 ✅ DONE
- [ ] **Task 5**: Verification & Testing (1 hour) - P0 🔄 IN PROGRESS

**Total Estimated Time**: 6.5 hours  
**Actual Time Spent**: ~3 hours

---

## Task 1: Fix Compilation Warnings ⚠️ [P0]

**Priority**: CRITICAL  
**Estimated**: 30 minutes  
**Status**: 🔄 In Progress

### Problem
```
warning: clauses with the same name and arity should be grouped together
lib/ui_web_web/live/messages_live.ex:32, 57, 177, 196
```

### Solution
Group all `handle_event/3` and `handle_info/2` clauses together in `messages_live.ex`

### Files to Edit
- `lib/ui_web_web/live/messages_live.ex`

### Acceptance Criteria
- [ ] All `handle_event/3` clauses grouped consecutively
- [ ] All `handle_info/2` clauses grouped consecutively
- [ ] `mix compile` produces zero warnings
- [ ] Code functionality unchanged

---

## Task 2: Migrate GatewayClient to Req 🔄 [P0]

**Priority**: CRITICAL (Project Guidelines Compliance)  
**Estimated**: 2 hours  
**Status**: 📅 Pending

### Problem
- Currently uses `Mint` directly (violates project guidelines)
- Project guidelines require `:req` HTTP client
- Missing connection pooling and retry logic

### Solution
Replace Mint HTTP calls with Req library:
- Use `Req.get/2` for GET requests
- Use `Req.post/2`, `Req.put/2`, `Req.delete/2` for mutations
- Leverage Req's built-in retries and connection pooling

### Files to Edit
- `lib/ui_web/services/gateway_client.ex`
- `mix.exs` (already has :req dependency)

### Acceptance Criteria
- [ ] All HTTP calls use `Req` instead of `Mint`
- [ ] Proper error handling maintained
- [ ] Connection pooling via Finch (automatic with Req)
- [ ] Retry logic configured (exponential backoff)
- [ ] Health check works
- [ ] Metrics endpoint works
- [ ] JSON parsing works
- [ ] All existing functionality preserved

### Code Changes Required
```elixir
# Before (Mint):
Mint.HTTP.connect(:http, host, port)
Mint.HTTP.request(conn, "GET", path, headers, "")

# After (Req):
Req.get(url, headers: headers, decode_body: true)
```

---

## Task 3: Fix API Endpoints 🔧 [P0]

**Priority**: CRITICAL (API Contract Compliance)  
**Estimated**: 1 hour  
**Status**: 📅 Pending

### Problem
- UI uses `/_health` but spec requires `/health`
- UI uses `/_metrics` but not documented in universal spec
- Inconsistency blocks integration with real Gateway

### Solution
Update endpoint paths in:
1. `GatewayClient` methods
2. Documentation references
3. Configuration if needed

### Files to Edit
- `lib/ui_web/services/gateway_client.ex`
- `lib/ui_web_web/live/dashboard_live.ex`
- `config/dev.exs` (comments/docs)
- `README.md`, `QUICKSTART.md` (update docs)

### Changes
```elixir
# gateway_client.ex
- def fetch_health(), do: get_json("/_health")
+ def fetch_health(), do: get_json("/health")

- def fetch_metrics(), do: get_json("/_metrics")
+ def fetch_metrics(), do: get_json("/metrics")  # or remove if not supported
```

### Acceptance Criteria
- [ ] Health endpoint uses `/health`
- [ ] Metrics endpoint uses `/metrics` OR is removed
- [ ] Dashboard LiveView updated
- [ ] Documentation updated
- [ ] No broken references

---

## Task 4: Enforce Authentication on /app/* 🔒 [P0]

**Priority**: CRITICAL (Security)  
**Estimated**: 2 hours  
**Status**: 📅 Pending

### Problem
- `/app/*` routes are publicly accessible
- No authentication enforcement
- Security vulnerability

### Solution
Add Guardian authentication pipeline to `/app/*` routes:

```elixir
# router.ex
scope "/app", UiWebWeb do
  pipe_through [:browser, :auth]  # Add :auth pipeline
  
  live "/dashboard", DashboardLive
  # ... other routes
end
```

Create `:auth` pipeline:
```elixir
pipeline :auth do
  plug UiWeb.Auth.Pipeline
  plug Guardian.Plug.EnsureAuthenticated
  plug :load_current_user
end
```

### Files to Edit
- `lib/ui_web_web/router.ex`
- `lib/ui_web/auth/pipeline.ex` (if needs updates)
- `config/config.exs` (Guardian config)
- `config/prod.exs` (production secrets)

### Acceptance Criteria
- [ ] `:auth` pipeline defined in router
- [ ] `/app/*` routes require authentication
- [ ] Unauthenticated users redirect to `/login`
- [ ] Guardian configured properly
- [ ] OIDC callback works
- [ ] Session handling works
- [ ] Current user accessible in LiveView (`@current_user`)

---

## Task 5: Verification & Testing ✅ [P0]

**Priority**: HIGH  
**Estimated**: 1 hour  
**Status**: 📅 Pending

### Verification Steps

#### 1. Compilation Check
```bash
cd apps/ui_web
mix compile --warnings-as-errors
```
**Expected**: No warnings, no errors

#### 2. Dependency Check
```bash
mix deps
```
**Expected**: All deps resolved, :req present

#### 3. Manual Testing
```bash
mix phx.server
```

Test scenarios:
- [ ] Navigate to `http://localhost:4000` - should work
- [ ] Navigate to `http://localhost:4000/app/dashboard` - should redirect to `/login`
- [ ] Login via OIDC - should work (if configured)
- [ ] After login, access dashboard - should work
- [ ] Health data loads from Gateway `/health`
- [ ] Metrics data loads from Gateway `/metrics`

#### 4. Integration Test (if Gateway running)
```bash
# Start Gateway (if available)
# Test all endpoints
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

#### 5. Update Project State
- [ ] Update `.trae/state.json` with UI-Web progress
- [ ] Create ADR for authentication enforcement
- [ ] Update `PROJECT_ANALYSIS_REPORT.md` with fixes

---

## 🎯 Success Criteria (All Tasks)

### Code Quality
- ✅ Zero compilation warnings
- ✅ Zero linter errors
- ✅ Project guidelines compliance (using :req)
- ✅ Zero-tolerance policy met

### Security
- ✅ Authentication enforced on all `/app/*` routes
- ✅ Proper session handling
- ✅ Secure redirects

### Integration
- ✅ Correct API endpoints (/health, /metrics)
- ✅ Gateway integration works
- ✅ SSE streaming maintained

### Documentation
- ✅ All changes documented
- ✅ ADR created if needed
- ✅ README/QUICKSTART updated

---

## 📝 Notes

### Dependencies Already Added
- `:req` ~> 0.4 ✅
- `:finch` 0.20.0 ✅ (via req)
- `:guardian` ~> 2.3 ✅
- `:ueberauth` ~> 0.10 ✅

### Risks & Mitigation
1. **Risk**: Req migration breaks SSE streaming
   - **Mitigation**: Keep SSEBridge using Mint (low-level streaming)
   
2. **Risk**: Auth breaks existing workflows
   - **Mitigation**: Test thoroughly, allow public pages (/, /login)
   
3. **Risk**: Gateway endpoints not available
   - **Mitigation**: Graceful fallback, clear error messages

---

## 🚀 Execution Order

1. ✅ Task 1: Fix warnings (quick win)
2. ✅ Task 2: Migrate to Req (foundation)
3. ✅ Task 3: Fix endpoints (contracts)
4. ✅ Task 4: Add auth (security)
5. ✅ Task 5: Verify (quality)

**Start Time**: 2025-11-22 14:31  
**Target Completion**: 2025-11-22 21:00 (6.5 hours)

---

**Last Updated**: 2025-11-22 14:31  
**Owner**: Windsurf Cascade  
**Status**: Task 1 Starting Now
