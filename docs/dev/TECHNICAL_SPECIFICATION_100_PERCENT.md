# Technical Specification: UI-Web 100% Completion

**Version**: 1.0  
**Date**: 2025-01-27  
**Status**: Draft  
**Target**: 100% compliance with `docs/UI_WEB_TECHNICAL_SPEC.md`

---

## Executive Summary

**Current State**: ~65% of technical specification completed  
**Target State**: 100% of technical specification  
**Estimated Time**: 6-9 weeks  
**Priority**: Complete critical features first, then enhancements

**Completion Status by Module**:
- Dashboard: 90% → **Target: 100%**
- Messages Management: 85% → **Target: 100%**
- Routing Policies Editor: 40% → **Target: 100%** 🔴 CRITICAL
- Extensions Registry: 80% → **Target: 100%**
- Usage & Billing: 0% → **Target: 100%** 🟡 HIGH
- Authentication: 70% → **Target: 100%**
- Real-time Features: 60% → **Target: 100%**

---

## Phase 1: Critical Missing Features (Priority 1)

**Estimated Time**: 3-4 weeks  
**Priority**: 🔴 CRITICAL

---

### Task 1.1: Visual Pipeline Builder for Policies

**Priority**: 🔴 **CRITICAL**  
**Estimated Time**: 2 weeks (10 working days)  
**Status**: 0% - Not started  
**Dependencies**: None

#### 1.1.1 Requirements

**Functional Requirements**:

1. **Visual Pipeline Builder Interface**:
   - Drag-and-drop interface for building routing policies
   - Visual representation of pipeline stages:
     - Pre-processors stage (top)
     - Validators stage
     - Providers stage
     - Post-processors stage (bottom)
   - Each stage displays as a horizontal container with extension cards
   - Visual flow indicators (arrows) between stages
   - Ability to reorder extensions within a stage via drag-and-drop

2. **Extension Cards**:
   - Display extension name, type, version
   - Show extension icon/badge
   - Display configuration summary (if configured)
   - Delete button (remove from pipeline)
   - Edit button (open configuration modal)
   - Drag handle for reordering

3. **Extension Selection**:
   - Modal/popover for selecting available extensions
   - Filter by extension type (pre-processor, validator, post-processor)
   - Search functionality
   - Display extension metadata (description, capabilities, version)
   - "Add to Pipeline" button

4. **Pipeline Operations**:
   - Add extension to specific stage
   - Remove extension from pipeline
   - Reorder extensions within stage
   - Move extension between stages (if applicable)
   - Clear entire stage
   - Duplicate extension within stage

5. **Bidirectional Sync with JSON Editor**:
   - Visual changes update JSON editor in real-time
   - JSON editor changes update visual builder in real-time
   - Validation: ensure JSON and visual representation are always in sync
   - Error handling: show validation errors in both views

6. **Dry-Run Testing**:
   - "Dry Run" button in UI
   - Test policy with sample message
   - Display results:
     - Routing decision
     - Provider selected
     - Extensions executed (with order)
     - Execution time per extension
     - Errors/warnings (if any)
   - Ability to test with custom message payload

7. **Version History**:
   - Display list of policy versions
   - Show version metadata (timestamp, author, changes summary)
   - Compare versions (diff view)
   - View version details

8. **Rollback Functionality**:
   - "Rollback to Version" button
   - Confirmation dialog
   - Restore policy to selected version
   - Create new version from rollback

#### 1.1.2 Technical Specifications

**Component Structure**:

```
lib/ui_web_web/
├── live/
│   └── policies_live/
│       ├── editor.ex              # Main editor LiveView
│       ├── editor.html.heex       # Editor template
│       ├── index.ex               # List view (existing)
│       └── index.html.heex        # List template (existing)
├── components/
│   ├── pipeline_builder.ex        # Main pipeline builder component
│   ├── pipeline_stage.ex          # Individual stage component
│   ├── extension_card.ex           # Extension card component
│   ├── extension_selector.ex       # Extension selection modal
│   ├── dry_run_panel.ex           # Dry-run results panel
│   └── version_history.ex         # Version history component
└── services/
    └── policies_client.ex         # API client (extend existing)
```

**LiveView Events**:

```elixir
# Extension management
handle_event("add_extension", %{"type" => type, "extension_id" => id, "stage" => stage}, socket)
handle_event("remove_extension", %{"stage" => stage, "index" => index}, socket)
handle_event("reorder_extension", %{"stage" => stage, "from_index" => from, "to_index" => to}, socket)

# Drag and drop
handle_event("drag_start", %{"extension_id" => id, "stage" => stage}, socket)
handle_event("drop_extension", %{"extension_id" => id, "stage" => stage, "index" => index}, socket)

# Pipeline operations
handle_event("clear_stage", %{"stage" => stage}, socket)
handle_event("duplicate_extension", %{"stage" => stage, "index" => index}, socket)

# Dry run
handle_event("dry_run", %{"test_message" => message}, socket)
handle_event("dry_run_with_custom", %{"message" => message}, socket)

# Version management
handle_event("load_version", %{"version_id" => id}, socket)
handle_event("rollback_to_version", %{"version_id" => id}, socket)
handle_event("compare_versions", %{"version1" => v1, "version2" => v2}, socket)

# Sync
handle_event("sync_to_json", _params, socket)
handle_event("sync_from_json", %{"json" => json}, socket)
```

**Data Structures**:

```elixir
# Policy structure
%{
  "policy_id" => "default",
  "tenant_id" => "tenant_dev",
  "pre" => [
    %{"extension_id" => "ext_1", "config" => %{}},
    %{"extension_id" => "ext_2", "config" => %{}}
  ],
  "validators" => [
    %{"extension_id" => "validator_1", "config" => %{}}
  ],
  "providers" => [
    %{"provider_id" => "openai:gpt-4", "priority" => 1, "config" => %{}}
  ],
  "post" => [
    %{"extension_id" => "post_1", "config" => %{}}
  ],
  "version" => 1,
  "created_at" => "2025-01-27T12:00:00Z",
  "updated_at" => "2025-01-27T12:00:00Z"
}

# Extension metadata
%{
  "id" => "ext_1",
  "name" => "PII Filter",
  "type" => "pre-processor",
  "version" => "1.0.0",
  "description" => "Filters PII from messages",
  "capabilities" => ["sync"],
  "config_schema" => %{...}
}
```

**API Endpoints** (Gateway):

```
GET    /api/v1/policies/:tenant_id/:policy_id/versions
GET    /api/v1/policies/:tenant_id/:policy_id/versions/:version_id
POST   /api/v1/policies/:tenant_id/:policy_id/dry-run
POST   /api/v1/policies/:tenant_id/:policy_id/rollback
GET    /api/v1/extensions?type=pre-processor
GET    /api/v1/extensions?type=validator
GET    /api/v1/extensions?type=post-processor
```

#### 1.1.3 UI/UX Specifications

**Layout**:

```
┌─────────────────────────────────────────────────────────┐
│ Edit Policy: default                                    │
├─────────────────────────────────────────────────────────┤
│ [JSON Editor] [Visual Builder] [Version History]       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Pre-processors                                          │
│  ┌──────┐ ┌──────┐ ┌──────┐  [+ Add Extension]         │
│  │ Ext1 │ │ Ext2 │ │ Ext3 │                            │
│  └──────┘ └──────┘ └──────┘                            │
│      ↓                                                   │
│  Validators                                              │
│  ┌──────┐ ┌──────┐        [+ Add Extension]            │
│  │ Val1 │ │ Val2 │                                      │
│  └──────┘ └──────┘                                      │
│      ↓                                                   │
│  Providers                                               │
│  ┌──────┐ ┌──────┐        [+ Add Provider]             │
│  │ Prov1│ │ Prov2│                                      │
│  └──────┘ └──────┘                                      │
│      ↓                                                   │
│  Post-processors                                         │
│  ┌──────┐        [+ Add Extension]                      │
│  │ Post1│                                                │
│  └──────┘                                                │
│                                                          │
│  [Dry Run] [Save Policy] [Cancel]                       │
└─────────────────────────────────────────────────────────┘
```

**Extension Card Design**:

```
┌─────────────────────────────┐
│ 🛡️ PII Filter        [×] [✎]│
│ Version: 1.0.0              │
│ Type: pre-processor          │
│ ─────────────────────────── │
│ Config: enabled=true        │
└─────────────────────────────┘
```

**Drag-and-Drop Behavior**:
- Visual feedback during drag (card becomes semi-transparent)
- Drop zones highlight when dragging over valid target
- Smooth animations for reordering
- Invalid drop zones show error indicator

**Responsive Design**:
- Desktop: Horizontal pipeline stages
- Tablet: Vertical pipeline stages (stacked)
- Mobile: Simplified view with expandable stages

#### 1.1.4 Implementation Steps

**Week 1: Core Components (5 days)**

**Day 1-2: Component Architecture**
- [ ] Create `PipelineBuilder` LiveComponent
- [ ] Create `PipelineStage` component
- [ ] Create `ExtensionCard` component
- [ ] Design data structures and state management
- [ ] Create wireframes/mockups

**Day 3-4: Basic Drag-and-Drop**
- [ ] Implement Phoenix LiveView drag-and-drop handlers
- [ ] Create JavaScript hooks for drag-and-drop (if needed)
- [ ] Implement basic drag start/drop events
- [ ] Add visual feedback during drag

**Day 5: Extension Selection**
- [ ] Create `ExtensionSelector` modal component
- [ ] Implement extension filtering and search
- [ ] Add "Add to Pipeline" functionality
- [ ] Test extension selection flow

**Week 2: Advanced Features (5 days)**

**Day 6-7: Pipeline Operations**
- [ ] Implement reorder within stage
- [ ] Implement remove extension
- [ ] Implement clear stage
- [ ] Add duplicate extension
- [ ] Test all pipeline operations

**Day 8: JSON Sync**
- [ ] Implement bidirectional sync (visual ↔ JSON)
- [ ] Add validation
- [ ] Handle sync errors
- [ ] Test sync in both directions

**Day 9: Dry-Run and Version History**
- [ ] Implement dry-run UI
- [ ] Create dry-run results panel
- [ ] Implement version history list
- [ ] Add version comparison view
- [ ] Implement rollback functionality

**Day 10: Testing and Polish**
- [ ] Write comprehensive tests
- [ ] Fix bugs
- [ ] UI/UX polish
- [ ] Documentation

#### 1.1.5 Acceptance Criteria

**Must Have**:
- ✅ Visual pipeline builder displays all 4 stages
- ✅ Drag-and-drop works for adding/reordering extensions
- ✅ Extension cards display correctly with all metadata
- ✅ Extension selection modal works
- ✅ Bidirectional sync with JSON editor works
- ✅ Dry-run testing works and displays results
- ✅ Version history displays and allows rollback
- ✅ All operations persist to Gateway API
- ✅ Error handling works for all operations
- ✅ Responsive design works on desktop/tablet/mobile

**Should Have**:
- ✅ Smooth animations for drag-and-drop
- ✅ Visual flow indicators between stages
- ✅ Extension configuration editing within cards
- ✅ Keyboard shortcuts for common operations
- ✅ Undo/redo functionality

**Nice to Have**:
- ✅ Policy templates
- ✅ Export/import policy as JSON
- ✅ Policy validation before save
- ✅ Collaborative editing indicators

#### 1.1.6 Test Requirements

**Unit Tests**:
- Component rendering tests
- Event handler tests
- State management tests
- Validation logic tests

**Integration Tests**:
- Full drag-and-drop flow
- JSON sync in both directions
- Dry-run execution
- Version history and rollback

**E2E Tests**:
- Create policy via visual builder
- Edit existing policy
- Test dry-run
- Rollback to previous version

**Test Coverage Target**: 80%+

---

### Task 1.2: Usage & Billing Dashboard

**Priority**: 🟡 **HIGH**  
**Estimated Time**: 1-2 weeks (5-10 working days)  
**Status**: 0% - Not started  
**Dependencies**: Gateway API for usage data

#### 1.2.1 Requirements

**Functional Requirements**:

1. **Per-Tenant Usage Statistics**:
   - Display usage metrics per tenant:
     - Total messages processed
     - Total tokens used (input + output)
     - Total cost (estimated)
     - Average latency
     - Error rate
   - Time range selector (last 24h, 7d, 30d, custom)
   - Tenant selector (if multi-tenant)
   - Real-time updates (every 5-10 seconds)

2. **Cost Estimation**:
   - Display estimated cost per tenant
   - Breakdown by provider (OpenAI, Anthropic, etc.)
   - Breakdown by message type (chat, completion, embedding)
   - Cost trends over time
   - Projected monthly cost

3. **Charts (Time Series)**:
   - Messages volume over time (line chart)
   - Cost over time (line chart)
   - Token usage over time (area chart)
   - Latency over time (line chart)
   - Error rate over time (line chart)
   - Provider distribution (pie chart)
   - Message type distribution (bar chart)

4. **Quota Management**:
   - Display current quota limits per tenant
   - Display quota usage (percentage)
   - Set/update quota limits
   - Quota warnings (when approaching limit)
   - Quota exceeded alerts

5. **Billing Reports**:
   - Generate billing reports (CSV/PDF)
   - Date range selection
   - Tenant selection
   - Report includes:
     - Usage summary
     - Cost breakdown
     - Provider breakdown
     - Message type breakdown
   - Download reports
   - Email reports (optional)

6. **Filters and Search**:
   - Filter by date range
   - Filter by tenant
   - Filter by provider
   - Filter by message type
   - Search functionality

#### 1.2.2 Technical Specifications

**Component Structure**:

```
lib/ui_web_web/
├── live/
│   └── usage_live/
│       ├── index.ex              # Main usage dashboard
│       └── index.html.heex       # Dashboard template
├── components/
│   ├── usage_chart.ex            # Chart component (reusable)
│   ├── quota_card.ex             # Quota display card
│   ├── cost_breakdown.ex         # Cost breakdown component
│   └── report_generator.ex       # Report generation component
└── services/
    └── usage_client.ex           # Usage API client
```

**LiveView Events**:

```elixir
# Filters
handle_event("filter_date_range", %{"from" => from, "to" => to}, socket)
handle_event("filter_tenant", %{"tenant_id" => id}, socket)
handle_event("filter_provider", %{"provider_id" => id}, socket)

# Reports
handle_event("generate_report", %{"format" => format, "date_range" => range}, socket)
handle_event("download_report", %{"report_id" => id}, socket)

# Quota
handle_event("update_quota", %{"tenant_id" => id, "quota" => quota}, socket)
```

**Data Structures**:

```elixir
# Usage statistics
%{
  "tenant_id" => "tenant_dev",
  "period" => %{"from" => "2025-01-01", "to" => "2025-01-27"},
  "metrics" => %{
    "total_messages" => 1250,
    "total_tokens" => %{
      "input" => 50000,
      "output" => 30000
    },
    "total_cost" => 12.50,
    "avg_latency_ms" => 250,
    "error_rate" => 0.02
  },
  "by_provider" => [
    %{"provider_id" => "openai:gpt-4", "messages" => 800, "cost" => 8.00},
    %{"provider_id" => "anthropic:claude", "messages" => 450, "cost" => 4.50}
  ],
  "by_type" => [
    %{"type" => "chat", "messages" => 1000, "cost" => 10.00},
    %{"type" => "completion", "messages" => 250, "cost" => 2.50}
  ],
  "time_series" => [
    %{"date" => "2025-01-27", "messages" => 50, "cost" => 0.50, "tokens" => 2000}
  ]
}

# Quota
%{
  "tenant_id" => "tenant_dev",
  "limits" => %{
    "messages_per_month" => 10000,
    "tokens_per_month" => 1000000,
    "cost_per_month" => 100.00
  },
  "usage" => %{
    "messages" => 7500,
    "tokens" => 750000,
    "cost" => 75.00
  },
  "percentages" => %{
    "messages" => 75.0,
    "tokens" => 75.0,
    "cost" => 75.0
  }
}
```

**API Endpoints** (Gateway):

```
GET    /api/v1/usage/:tenant_id?from=DATE&to=DATE
GET    /api/v1/usage/:tenant_id/summary?period=24h|7d|30d
GET    /api/v1/usage/:tenant_id/cost?period=PERIOD
GET    /api/v1/usage/:tenant_id/quota
PUT    /api/v1/usage/:tenant_id/quota
POST   /api/v1/usage/:tenant_id/reports
GET    /api/v1/usage/:tenant_id/reports/:report_id
```

#### 1.2.3 UI/UX Specifications

**Layout**:

```
┌─────────────────────────────────────────────────────────┐
│ Usage & Billing                                         │
├─────────────────────────────────────────────────────────┤
│ [Tenant: tenant_dev ▼] [Last 7 days ▼] [Generate Report]│
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │ Messages    │ │ Cost        │ │ Tokens      │      │
│  │ 1,250       │ │ $12.50      │ │ 80,000      │      │
│  │ +15% vs prev│ │ +12% vs prev│ │ +18% vs prev│      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Messages Volume Over Time                        │   │
│  │ [Line Chart]                                     │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────┐ ┌──────────────────┐             │
│  │ Cost Over Time   │ │ Provider Dist.   │             │
│  │ [Line Chart]     │ │ [Pie Chart]     │             │
│  └──────────────────┘ └──────────────────┘             │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Quota Management                                 │   │
│  │ Messages: [████████░░] 75% (7,500 / 10,000)     │   │
│  │ Tokens:   [████████░░] 75% (750K / 1M)          │   │
│  │ Cost:     [████████░░] 75% ($75 / $100)         │   │
│  │ [Update Quota]                                   │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Chart Library**: Chart.js or Recharts (via JavaScript hooks)

**Responsive Design**:
- Desktop: 2-column layout for charts
- Tablet: Single column, stacked charts
- Mobile: Simplified view with key metrics only

#### 1.2.4 Implementation Steps

**Week 1: Core Dashboard (5 days)**

**Day 1-2: Basic Structure**
- [ ] Create `UsageLive` module
- [ ] Create basic layout and routing
- [ ] Implement API client (`UsageClient`)
- [ ] Add filters (date range, tenant)

**Day 3-4: Statistics and Charts**
- [ ] Implement usage statistics display
- [ ] Add Chart.js integration
- [ ] Create time series charts
- [ ] Add cost breakdown charts

**Day 5: Quota Management**
- [ ] Implement quota display
- [ ] Add quota update functionality
- [ ] Add quota warnings/alerts
- [ ] Test quota management

**Week 2: Reports and Polish (5 days)**

**Day 6-7: Billing Reports**
- [ ] Implement report generation
- [ ] Add CSV export
- [ ] Add PDF export (if library available)
- [ ] Add report download functionality

**Day 8-9: Enhancements**
- [ ] Add real-time updates
- [ ] Improve chart interactivity
- [ ] Add export functionality for charts
- [ ] Add email reports (optional)

**Day 10: Testing and Polish**
- [ ] Write comprehensive tests
- [ ] Fix bugs
- [ ] UI/UX polish
- [ ] Documentation

#### 1.2.5 Acceptance Criteria

**Must Have**:
- ✅ Usage statistics display correctly
- ✅ Charts render and update correctly
- ✅ Date range filtering works
- ✅ Cost estimation is accurate
- ✅ Quota management works
- ✅ Reports can be generated and downloaded
- ✅ Real-time updates work
- ✅ Responsive design works

**Should Have**:
- ✅ Interactive charts (tooltips, zoom)
- ✅ Export charts as images
- ✅ Email reports
- ✅ Quota alerts/notifications

**Nice to Have**:
- ✅ Cost predictions/forecasting
- ✅ Usage recommendations
- ✅ Automated reports (scheduled)

#### 1.2.6 Test Requirements

**Unit Tests**:
- Statistics calculation
- Cost estimation logic
- Quota validation

**Integration Tests**:
- API integration
- Chart rendering
- Report generation

**E2E Tests**:
- View usage dashboard
- Generate and download report
- Update quota

**Test Coverage Target**: 75%+

---

## Phase 2: Enhance Existing Features (Priority 2)

**Estimated Time**: 2-3 weeks  
**Priority**: 🟡 MEDIUM

---

### Task 2.1: Messages Management Enhancements

**Priority**: 🟡 **MEDIUM**  
**Estimated Time**: 1 week (5 working days)  
**Status**: 85% - Core features complete  
**Dependencies**: Gateway API for retry/cancel

#### 2.1.1 Requirements

**Functional Requirements**:

1. **Retry/Cancel Actions**:
   - "Retry" button for failed messages
   - "Cancel" button for pending/processing messages
   - Confirmation dialogs
   - Success/error feedback
   - Real-time status updates after action

2. **Message Detail Modal**:
   - Convert message detail page to modal
   - Modal opens from message list
   - Display full message details:
     - Message ID, tenant, type, status
     - Payload (formatted JSON)
     - Response (if available)
     - Trace information
     - Timestamps (created, updated, completed)
   - Actions within modal:
     - Retry (if failed)
     - Cancel (if pending/processing)
     - Delete
     - Export
   - Close modal (ESC key or close button)

3. **Enhanced Trace Correlation UI**:
   - Display trace ID prominently
   - Link to trace view (if implemented)
   - Show related messages in same trace
   - Visual trace timeline
   - Filter messages by trace ID

#### 2.1.2 Technical Specifications

**New Events**:

```elixir
# Retry/Cancel
handle_event("retry_message", %{"id" => id}, socket)
handle_event("cancel_message", %{"id" => id}, socket)

# Modal
handle_event("show_message_detail", %{"id" => id}, socket)
handle_event("close_message_detail", _params, socket)
```

**API Endpoints** (Gateway):

```
POST   /api/v1/messages/:id/retry
POST   /api/v1/messages/:id/cancel
GET    /api/v1/messages?trace_id=TRACE_ID
```

#### 2.1.3 Implementation Steps

**Day 1-2: Retry/Cancel Actions**
- [ ] Add retry/cancel buttons to message list
- [ ] Implement API calls
- [ ] Add confirmation dialogs
- [ ] Handle success/error states
- [ ] Test retry/cancel flow

**Day 3-4: Message Detail Modal**
- [ ] Create modal component
- [ ] Convert show page to modal
- [ ] Add modal open/close handlers
- [ ] Move actions to modal
- [ ] Add keyboard shortcuts (ESC to close)
- [ ] Test modal functionality

**Day 5: Trace Correlation**
- [ ] Enhance trace ID display
- [ ] Add trace filtering
- [ ] Add related messages view
- [ ] Test trace correlation

#### 2.1.4 Acceptance Criteria

- ✅ Retry works for failed messages
- ✅ Cancel works for pending/processing messages
- ✅ Message detail modal displays correctly
- ✅ Modal can be opened/closed
- ✅ Trace correlation UI works
- ✅ All actions provide feedback

---

### Task 2.2: Dashboard Enhancements

**Priority**: 🟡 **MEDIUM**  
**Estimated Time**: 1 week (5 working days)  
**Status**: 90% - Core features complete

#### 2.2.1 Requirements

**Functional Requirements**:

1. **Metrics History Charts**:
   - Throughput over time (line chart)
   - Latency over time (line chart)
   - Error rate over time (line chart)
   - Time range selector (1h, 6h, 24h, 7d)
   - Interactive charts (zoom, pan, tooltips)

2. **Recent Alerts Section**:
   - Display recent system alerts
   - Alert types: error, warning, info
   - Alert metadata (timestamp, component, message)
   - Link to alert details
   - Dismiss alerts
   - Filter by severity

3. **Quick Stats Cards**:
   - Messages today (count)
   - Policies count
   - Extensions count
   - Active tenants count
   - Click to navigate to relevant page

#### 2.2.2 Implementation Steps

**Day 1-2: Metrics History Charts**
- [ ] Add Chart.js integration
- [ ] Create metrics history API endpoint (or use existing)
- [ ] Implement time range selector
- [ ] Create charts for throughput, latency, error rate
- [ ] Add interactivity (zoom, pan, tooltips)

**Day 3: Recent Alerts**
- [ ] Create alerts data structure
- [ ] Implement alerts display component
- [ ] Add alert filtering
- [ ] Add dismiss functionality
- [ ] Test alerts display

**Day 4: Quick Stats**
- [ ] Create quick stats cards
- [ ] Fetch statistics from API
- [ ] Add navigation links
- [ ] Test quick stats

**Day 5: Testing and Polish**
- [ ] Write tests
- [ ] Fix bugs
- [ ] UI/UX polish

#### 2.2.3 Acceptance Criteria

- ✅ Metrics history charts display correctly
- ✅ Charts are interactive
- ✅ Recent alerts display correctly
- ✅ Quick stats cards work
- ✅ All navigation links work

---

### Task 2.3: Real-time Optimization

**Priority**: 🟡 **MEDIUM**  
**Estimated Time**: 1 week (5 working days)  
**Status**: 60% - Basic PubSub working

#### 2.3.1 Requirements

**Functional Requirements**:

1. **Selective Broadcasting**:
   - Only broadcast to relevant LiveViews
   - Filter by tenant_id
   - Filter by message type
   - Filter by extension type
   - Reduce unnecessary updates

2. **Reconnection Handling**:
   - Automatic reconnection with exponential backoff
   - Visual indicator when disconnected
   - Queue messages during disconnection
   - Replay queued messages on reconnect

3. **Offline Mode Detection**:
   - Detect offline state
   - Show offline indicator
   - Queue actions for when online
   - Sync queued actions on reconnect

4. **State Persistence**:
   - Persist LiveView state to localStorage
   - Restore state on page reload
   - Handle state conflicts

5. **Rate Limiting**:
   - Limit update frequency (max 10 updates/second per LiveView)
   - Batch updates
   - Throttle rapid events

#### 2.3.2 Implementation Steps

**Day 1: Selective Broadcasting**
- [ ] Implement tenant-based filtering
- [ ] Add message type filtering
- [ ] Optimize PubSub subscriptions
- [ ] Test selective broadcasting

**Day 2: Reconnection Handling**
- [ ] Implement exponential backoff
- [ ] Add reconnection logic
- [ ] Add visual indicators
- [ ] Test reconnection

**Day 3: Offline Mode**
- [ ] Add offline detection
- [ ] Implement action queue
- [ ] Add sync on reconnect
- [ ] Test offline mode

**Day 4: State Persistence**
- [ ] Implement localStorage persistence
- [ ] Add state restoration
- [ ] Handle conflicts
- [ ] Test state persistence

**Day 5: Rate Limiting**
- [ ] Implement rate limiting
- [ ] Add batching
- [ ] Test rate limiting
- [ ] Performance testing

#### 2.3.3 Acceptance Criteria

- ✅ Selective broadcasting works
- ✅ Reconnection works automatically
- ✅ Offline mode is detected and handled
- ✅ State persists across page reloads
- ✅ Rate limiting prevents overload

---

## Phase 3: Production Readiness (Priority 3)

**Estimated Time**: 1-2 weeks  
**Priority**: 🟢 LOW (but required for production)

---

### Task 3.1: Authentication Production Setup

**Priority**: 🟢 **LOW**  
**Estimated Time**: 3-5 days  
**Status**: 70% - Structure ready

#### 3.1.1 Requirements

**Functional Requirements**:

1. **Production OIDC Configuration**:
   - Support multiple OIDC providers (Keycloak, Auth0, Okta)
   - Environment-based configuration
   - Secure secret management
   - Provider discovery

2. **Token Refresh Handling**:
   - Automatic token refresh before expiration
   - Refresh token storage
   - Handle refresh failures
   - Re-authentication flow

3. **Multi-Tenant User Context**:
   - User tenant association
   - Tenant switching UI
   - Tenant-scoped data access
   - Tenant isolation

4. **Role-Based Access Control (RBAC)**:
   - User roles (admin, user, viewer)
   - Permission checking
   - Route protection by role
   - UI element visibility by role

5. **Session Management**:
   - Session timeout handling
   - Idle timeout
   - Session renewal
   - Logout on timeout

#### 3.1.2 Implementation Steps

**Day 1: Production OIDC**
- [ ] Configure production OIDC providers
- [ ] Add environment variables
- [ ] Test OIDC flow
- [ ] Document configuration

**Day 2: Token Refresh**
- [ ] Implement token refresh logic
- [ ] Add refresh token storage
- [ ] Handle refresh failures
- [ ] Test token refresh

**Day 3: Multi-Tenant Context**
- [ ] Add tenant association
- [ ] Implement tenant switching
- [ ] Add tenant-scoped access
- [ ] Test multi-tenant

**Day 4: RBAC**
- [ ] Define roles and permissions
- [ ] Implement permission checking
- [ ] Add route protection
- [ ] Test RBAC

**Day 5: Session Management**
- [ ] Implement session timeout
- [ ] Add idle timeout
- [ ] Test session management
- [ ] Documentation

#### 3.1.3 Acceptance Criteria

- ✅ Production OIDC works
- ✅ Token refresh works automatically
- ✅ Multi-tenant context works
- ✅ RBAC works correctly
- ✅ Session management works

---

### Task 3.2: Extensions Registry Enhancements

**Priority**: 🟢 **LOW**  
**Estimated Time**: 3-5 days  
**Status**: 80% - Core features complete

#### 3.2.1 Requirements

**Functional Requirements**:

1. **Health History Graphs**:
   - Health status over time (line chart)
   - Latency over time (line chart)
   - Uptime percentage
   - Health trend indicators

2. **Configuration Validation UI**:
   - Validate extension configuration before save
   - Display validation errors
   - Highlight invalid fields
   - Provide validation feedback

3. **Extension Logs Viewer**:
   - Display extension logs
   - Filter by log level (error, warn, info)
   - Search logs
   - Real-time log streaming
   - Export logs

4. **Health Check Interval Configuration**:
   - Configure health check frequency per extension
   - Default intervals
   - Custom intervals
   - Health check timeout configuration

#### 3.2.2 Implementation Steps

**Day 1: Health History**
- [ ] Create health history data structure
- [ ] Implement health history API
- [ ] Create health history charts
- [ ] Test health history

**Day 2: Configuration Validation**
- [ ] Implement validation logic
- [ ] Add validation UI
- [ ] Display validation errors
- [ ] Test validation

**Day 3: Logs Viewer**
- [ ] Create logs viewer component
- [ ] Implement log filtering
- [ ] Add log search
- [ ] Test logs viewer

**Day 4: Health Check Configuration**
- [ ] Add health check interval configuration
- [ ] Implement timeout configuration
- [ ] Test health check configuration

**Day 5: Testing and Polish**
- [ ] Write tests
- [ ] Fix bugs
- [ ] UI/UX polish

#### 3.2.3 Acceptance Criteria

- ✅ Health history graphs display correctly
- ✅ Configuration validation works
- ✅ Logs viewer works
- ✅ Health check configuration works

---

## Testing Requirements

### Overall Test Coverage Target: 80%+

**Unit Tests**:
- All components
- All services
- All utilities
- Business logic

**Integration Tests**:
- LiveView flows
- API integration
- Real-time updates
- State management

**E2E Tests**:
- Critical user flows
- Cross-browser testing
- Mobile responsiveness

**Performance Tests**:
- Load testing
- Stress testing
- Real-time update performance

---

## Documentation Requirements

### Code Documentation
- [ ] All public functions have `@doc` comments
- [ ] Complex logic has inline comments
- [ ] Architecture decisions documented

### User Documentation
- [ ] User guide for each feature
- [ ] Screenshots/videos for complex features
- [ ] FAQ section

### Developer Documentation
- [ ] Setup instructions
- [ ] Architecture overview
- [ ] API documentation
- [ ] Testing guide

---

## Success Metrics

### Feature Completion
- **Target**: 100% of technical specification
- **Current**: ~65%
- **Gap**: 35%

### Quality Metrics
- **Test Coverage**: 80%+
- **Code Quality**: No linter errors, type safety
- **Performance**: <2s initial load, <100ms real-time updates

### User Experience
- **Accessibility**: WCAG 2.1 AA compliance
- **Responsive**: Works on desktop, tablet, mobile
- **Usability**: Intuitive, easy to use

---

## Timeline Summary

| Phase | Tasks | Estimated Time | Priority |
|-------|-------|----------------|----------|
| **Phase 1** | Visual Pipeline Builder, Usage & Billing | 3-4 weeks | 🔴 CRITICAL |
| **Phase 2** | Messages Enhancements, Dashboard Enhancements, Real-time Optimization | 2-3 weeks | 🟡 MEDIUM |
| **Phase 3** | Auth Production, Extensions Enhancements | 1-2 weeks | 🟢 LOW |
| **Total** | All tasks | **6-9 weeks** | |

---

## Dependencies

### External Dependencies
- Gateway API endpoints (for usage, policies, etc.)
- Chart library (Chart.js or Recharts)
- OIDC provider (for production auth)
- PDF generation library (for reports)

### Internal Dependencies
- Existing LiveView infrastructure
- PubSub system
- Gateway client
- Test infrastructure

---

## Risk Assessment

### High Risk
- **Visual Pipeline Builder complexity**: Drag-and-drop can be complex
  - **Mitigation**: Use proven libraries, start with simple implementation
- **Gateway API availability**: Some endpoints may not exist
  - **Mitigation**: Coordinate with backend team, create mock endpoints

### Medium Risk
- **Performance**: Real-time updates may impact performance
  - **Mitigation**: Implement rate limiting, optimize broadcasting
- **Browser compatibility**: Drag-and-drop may not work in all browsers
  - **Mitigation**: Test in multiple browsers, provide fallback

### Low Risk
- **Chart library integration**: May have compatibility issues
  - **Mitigation**: Use well-maintained libraries, test thoroughly

---

## Approval and Sign-off

**Technical Specification**: `docs/UI_WEB_TECHNICAL_SPEC.md`  
**Current Status Report**: `apps/ui_web/docs/dev/DEVELOPMENT_STATUS_REPORT.md`  
**This Specification**: `apps/ui_web/docs/dev/TECHNICAL_SPECIFICATION_100_PERCENT.md`

**Next Steps**:
1. Review and approve this specification
2. Prioritize tasks based on business needs
3. Assign resources
4. Begin Phase 1 implementation

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-27  
**Next Review**: After Phase 1 completion

