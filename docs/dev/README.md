# UI-Web: Phoenix LiveView UI for Beamline Constructor

**Status**: 🚧 In Development  
**Technology**: Elixir + Phoenix + LiveView  
**Replaces**: SvelteKit UI (`frontend/`)

---

## Overview

Phoenix LiveView UI provides a unified BEAM stack for Beamline Constructor:
- **Server-rendered** HTML with WebSocket diffs
- **Real-time** updates without heavy JavaScript
- **Same runtime** as Router (Erlang/OTP)
- **Simplified** deployment (no separate frontend build)

---

## Prerequisites

### Install Elixir & Erlang

**Ubuntu/Debian:**
```bash
# Add Erlang Solutions repository
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt-get update

# Install Erlang/OTP 26
sudo apt-get install -y esl-erlang

# Install Elixir 1.15
sudo apt-get install -y elixir
```

**macOS:**
```bash
brew install elixir
```

**Verify installation:**
```bash
elixir --version
# Erlang/OTP 26 [erts-14.x]
# Elixir 1.15.x
```

### Install Phoenix

```bash
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force
```

---

## Project Setup

### Step 1: Create Phoenix Project

```bash
cd apps
mix phx.new ui_web --no-ecto --live

# Answer prompts:
# Fetch and install dependencies? [Yn] Y
```

### Step 2: Install Dependencies

```bash
cd ui_web
mix deps.get
```

### Step 3: Configure Environment

**Copy example environment file:**
```bash
cp .env.example .env
# Edit .env with your values
```

**Or create `.env` file manually:**
```bash
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export GATEWAY_URL=http://localhost:8080
export GATEWAY_TIMEOUT=30000
export NATS_URL=nats://localhost:4222
export PHX_HOST=localhost
export PHX_PORT=4000
export OIDC_ENABLED=false
```

**Load environment:**
```bash
source .env
```

**For testing:**
```bash
# Unit tests (no Gateway required)
mix test --exclude integration

# Integration tests (requires Mock Gateway or real C-Gateway)
GATEWAY_URL=http://localhost:8080 mix test --only integration

# All tests
mix test
```

### Step 4: Start Development Server

```bash
mix phx.server
```

Visit: http://localhost:4000

---

## Project Structure

```
apps/ui-web/
├── assets/
│   ├── css/
│   │   └── app.css              # TailwindCSS
│   ├── js/
│   │   └── app.js               # Minimal JS (LiveView hooks)
│   └── vendor/
├── lib/
│   ├── ui_web/
│   │   ├── channels/            # Phoenix Channels
│   │   ├── components/          # LiveView Components
│   │   ├── controllers/         # HTTP Controllers
│   │   ├── live/                # LiveView Pages
│   │   │   ├── dashboard_live.ex
│   │   │   ├── messages_live/
│   │   │   ├── policies_live/
│   │   │   ├── extensions_live/
│   │   │   └── usage_live/
│   │   ├── router.ex            # Phoenix Router
│   │   ├── endpoint.ex          # Phoenix Endpoint
│   │   └── telemetry.ex         # Telemetry
│   ├── ui_web.ex
│   └── ui_web_application.ex    # OTP Application
├── priv/
│   ├── static/                  # Compiled assets
│   └── gettext/                 # I18n
├── test/
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   └── test.exs
├── mix.exs                      # Dependencies
└── README.md
```

---

## Development Workflow

### Hot Reload

Phoenix supports hot code reloading:
- Edit `.ex` files → auto-reload
- Edit `.heex` templates → auto-reload
- Edit CSS → auto-reload

### Run Tests

```bash
mix test
```

### Format Code

```bash
mix format
```

### Check Code Quality

```bash
mix credo
mix dialyzer
```

---

## Key Features

### 1. Dashboard (Real-time Metrics)
- System health monitoring
- Real-time throughput/latency charts
- Component status (C-Gateway, Router, Worker CAF)

### 2. Messages Management
- CRUD operations
- Real-time status updates
- Trace correlation
- Filtering and pagination

### 3. Routing Policies Editor ⭐
- Visual pipeline builder (drag-and-drop)
- JSON editor (fallback)
- Dry-run testing
- Version history

### 4. Extensions Registry UI ⭐
- List/Register/Edit extensions
- Health monitoring
- Enable/disable toggle
- Configuration editor

### 5. Usage & Billing
- Per-tenant usage statistics
- Cost estimation
- Quota management
- Reports export (CSV/PDF)

---

## Architecture

### Communication Flow

```
Browser (LiveView Client)
    ↕ WebSocket (Phoenix Channel)
Phoenix LiveView Server (Elixir)
    ↕ HTTP/REST
C-Gateway (C11)
    ↕ NATS
Router (Erlang/OTP)
```

### Real-time Updates

**Phoenix PubSub:**
- Metrics updates → Dashboard
- Message status → Messages page
- Extension health → Extensions page

**NATS Subscriber:**
- Subscribe to `beamline.messages.updates.v1`
- Subscribe to `beamline.metrics.v1`
- Broadcast to Phoenix PubSub

---

## Deployment

### Docker Build

```bash
docker build -t beamline/ui-web .
```

### docker-compose

```yaml
services:
  ui-web:
    build: ./apps/ui-web
    ports:
      - "4000:4000"
    environment:
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - GATEWAY_URL=http://c-gateway:8080
      - NATS_URL=nats://nats:4222
    depends_on:
      - c-gateway
      - nats
```

### Production Release

```bash
MIX_ENV=prod mix release
_build/prod/rel/ui_web/bin/ui_web start
```

---

## Documentation

- **Technical Spec**: `docs/UI_WEB_TECHNICAL_SPEC.md`
- **Implementation Plan**: `docs/UI_WEB_IMPLEMENTATION_PLAN.md`
- **Gateway Integration**: `docs/UI_WEB_GATEWAY_INTEGRATION.md` - HTTP integration with C-Gateway
- **Real-time Updates**: `docs/UI_WEB_REALTIME.md` - NATS and Phoenix PubSub integration
- **ADR-017**: `docs/ADR/ADR-017-phoenix-liveview-ui.md`
- **Phoenix Guides**: https://hexdocs.pm/phoenix/overview.html
- **LiveView Guide**: https://hexdocs.pm/phoenix_live_view/

---

## Migration from SvelteKit

### Why Phoenix LiveView?

✅ **Unified BEAM stack** (Elixir + Erlang)  
✅ **Simplified architecture** (no separate frontend)  
✅ **Better real-time** (LiveView + Channels)  
✅ **Faster development** (Phoenix generators)  
✅ **Hot reload** (BEAM feature)

### Migration Status

- ✅ ADR-017 created
- ✅ Technical Spec written
- ✅ Implementation Plan ready
- 🚧 Project setup (waiting for Elixir installation)
- 📅 Phase 1: Setup (2 days)
- 📅 Phase 2: Core Pages (5 days)
- 📅 Phase 3: Real-time (3 days)
- 📅 Phase 4: Deployment (2 days)

**Total**: 12 days

---

## Next Steps

1. **Install Elixir/Erlang** (see Prerequisites)
2. **Create Phoenix project**: `mix phx.new ui_web --no-ecto --live`
3. **Follow Implementation Plan**: `docs/UI_WEB_IMPLEMENTATION_PLAN.md`
4. **Start with Dashboard** (Day 3)
5. **Implement core pages** (Day 4-7)

---

## Support

- Phoenix Forum: https://elixirforum.com/c/phoenix-forum
- Elixir Slack: https://elixir-slackin.herokuapp.com/
- LiveView Docs: https://hexdocs.pm/phoenix_live_view/

---

**Status**: Ready for implementation after Elixir installation  
**Estimated**: 12 days to feature parity with SvelteKit  
**Target**: Replace `frontend/` completely
