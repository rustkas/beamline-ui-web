# UI-Web Quick Start Guide

**Goal**: Get Phoenix LiveView UI running in 3-4 hours

---

## 🚀 Quick Start (4 Steps)

### **Step 1: Install Elixir** (1 hour)

```bash
# Ubuntu/Debian
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt-get update
sudo apt-get install -y esl-erlang elixir

# Verify
elixir --version
```

### **Step 2: Install Phoenix** (30 min)

```bash
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force
```

### **Step 3: Create & Setup Project** (1.5 hours)

```bash
cd /home/rustkas/aigroup/apps
mix phx.new ui_web --no-ecto --live
cd ui_web

# Install dependencies
mix deps.get
# Phoenix 1.8 uses mix-based assets (esbuild/tailwind), npm is not required
# mix assets.setup && mix assets.build

# Generate secrets
mix phx.gen.secret  # → update .env: SECRET_KEY_BASE
mix guardian.gen.secret  # → update .env: GUARDIAN_SECRET_KEY
source .env
```

### **Step 4: Run & Verify** (30 min)

```bash
mix phx.server

# Open browser:
# http://localhost:4000
# http://localhost:4000/login
# http://localhost:4000/dev/dashboard
```

---

## ✅ What's Already Done

All configuration files, authentication modules, layouts, and Dashboard LiveView are **already created**:

- ✅ `.env` - Environment variables
- ✅ `config/dev.exs`, `config/config.exs` - Configuration
- ✅ `lib/ui_web/auth/*` - Authentication (Guardian, Ueberauth)
- ✅ `lib/ui_web/router.ex` - Router with auth pipelines
- ✅ `lib/ui_web/components/layouts/*` - Layouts
- ✅ `lib/ui_web/live/dashboard_live.ex` - Dashboard
- ✅ `assets/tailwind.config.js`, `assets/css/app.css` - Styling

**You only need to install Elixir and run the project!**

---

## 📚 Full Documentation

- **Quick Checklist**: `PHASE1_CHECKLIST.md`
- **Detailed Status**: `STATUS.md`
- **Full Setup Guide**: `docs/dev/PHASE1_UI_WEB_PROJECT_SETUP.md`
- **Why LiveView**: `docs/WHY_PHOENIX_LIVEVIEW.md`

---

## 🧭 Core Pages (require Gateway)

UI pages depend on Gateway API for data. Set `GATEWAY_URL` (dev default: `http://localhost:8080`).

- `/app/dashboard` → `GET ${GATEWAY_URL}/_health`
- `/app/messages` → `GET/POST ${GATEWAY_URL}/api/v1/messages`
- `/app/policies` → `GET/PUT/DELETE ${GATEWAY_URL}/api/v1/policies/*`
- `/app/extensions` → `GET ${GATEWAY_URL}/api/v1/registry/blocks[/:type]`

---

## 🚨 Troubleshooting

**Problem**: `mix` not found  
**Solution**: Install Elixir (see Step 1)

**Problem**: Phoenix generator not found  
**Solution**: `mix archive.install hex phx_new --force`

**Problem**: Port 4000 in use  
**Solution**: `lsof -ti:4000 | xargs kill -9`

---

**Ready to start? Follow Step 1!** 🎉
