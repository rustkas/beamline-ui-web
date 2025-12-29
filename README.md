# Beamline UI Web

> Phoenix LiveView web interface for the Beamline workflow orchestration platform

[![Phoenix](https://img.shields.io/badge/Phoenix-1.8.1-orange.svg)](https://www.phoenixframework.org/)
[![Elixir](https://img.shields.io/badge/Elixir-1.15+-purple.svg)](https://elixir-lang.org/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

## 📋 Overview

Beamline UI Web is a modern, real-time web interface built with Phoenix LiveView for managing and monitoring workflow orchestration on the Beamline platform. It provides an intuitive dashboard for creating, managing, and visualizing workflow executions, extensions, and messages.

## ✨ Features

### Core Functionality
- 🎯 **Dashboard** - Real-time workflow monitoring and statistics
- 🔌 **Extensions Management** - Create and manage workflow extensions
- 📨 **Messages System** - Publish and view messages with pagination
- 🔄 **Real-time Updates** - SSE (Server-Sent Events) for live data streaming
- 🎨 **Modern UI** - Built with TailwindCSS and DaisyUI components

### Technical Capabilities
- ⚡ **Phoenix LiveView** - Real-time, server-rendered UI components
- 🔐 **Authentication** - OIDC/OAuth2 integration via Guardian/Ueberauth
- 📊 **Telemetry** - Comprehensive metrics and monitoring
- 🧪 **E2E Testing** - Playwright-based end-to-end tests
- 📖 **API Integration** - RESTful communication with C-Gateway
- 🎨 **Code Preview** - Syntax highlighting for JSON/code blocks
- 🔗 **URL Previews** - Automatic rich link previews

## 🚀 Quick Start

### Prerequisites

- Elixir 1.15 or higher
- Erlang/OTP 26 or higher
- Node.js 18+ (for assets)
- PostgreSQL (optional, if using database)

### Installation

```bash
# Clone the repository
git clone https://github.com/rustkas/beamline-ui-web.git
cd beamline-ui-web

# Install dependencies
mix setup

# Configure environment (copy and edit)
cp .env.example .env
# Edit .env with your configuration

# Start the Phoenix server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) in your browser.

### Development Mode

```bash
# Run with IEx for interactive debugging
iex -S mix phx.server

# Run tests
mix test

# Run tests with coverage
mix test.coverage

# Run E2E tests (requires running server)
cd test/e2e
npm install
npx playwright test
```

## 📦 Project Structure

```
ui_web/
├── assets/              # Frontend assets (CSS, JS)
├── config/              # Application configuration
│   ├── config.exs      # General config
│   ├── dev.exs         # Development config
│   ├── prod.exs        # Production config
│   └── test.exs        # Test config
├── docs/                # Documentation
│   └── dev/            # Development docs
├── lib/
│   ├── ui_web/         # Business logic
│   │   ├── auth/       # Authentication modules
│   │   ├── contracts/  # API specifications
│   │   ├── messages/   # Message handling
│   │   ├── realtime/   # SSE and real-time
│   │   ├── schemas/    # Data schemas
│   │   ├── services/   # External service clients
│   │   └── telemetry/  # Metrics and monitoring
│   └── ui_web_web/     # Web layer (Phoenix)
│       ├── components/ # LiveView components
│       ├── controllers/# HTTP controllers
│       ├── live/       # LiveView pages
│       └── router.ex   # Routes
├── priv/                # Static assets
├── scripts/             # Utility scripts
├── test/                # Test suite
│   ├── e2e/            # Playwright E2E tests
│   └── support/        # Test helpers
└── mix.exs             # Project dependencies
```

## 🛠️ Configuration

Create a `.env` file based on `.env.example`:

```bash
# Gateway Configuration
GATEWAY_BASE_URL=http://localhost:8080

# Authentication
AUTH_ENABLED=false  # Set to true for OIDC
OIDC_DISCOVERY_URL=https://your-oidc-provider/.well-known/openid-configuration
OIDC_CLIENT_ID=your-client-id
OIDC_CLIENT_SECRET=your-secret

# Server
PORT=4000
SECRET_KEY_BASE=generate-with-mix-phx-gen-secret

# External Services
NATS_URL=nats://localhost:4222
```

## 🧪 Testing

### Unit & Integration Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/ui_web_web/live/dashboard_live_test.exs

# Run with coverage
mix test.coverage

# Watch mode (requires filesystem watcher)
mix test.watch
```

### E2E Tests

```bash
# Setup E2E tests
cd test/e2e
npm install

# Run E2E tests
npx playwright test

# Run in UI mode
npx playwright test --ui

# Generate HTML report
npx playwright show-report
```

### Property-Based Tests

Property-based tests using StreamData are included for critical components:

```bash
# Run property tests
mix test test/ui_web/messages/pagination_logic_property_test.exs
```

## 📊 Key Components

### Dashboard
Real-time workflow monitoring with:
- Active flows count
- Success/failure rates
- Resource usage metrics
- Recent activity feed

### Extensions
Manage workflow extensions:
- Create/update/delete extensions
- Pipeline editor
- Schema validation
- Extension marketplace (coming soon)

### Messages
Message management system:
- Publish messages
- View message history
- Pagination support
- Real-time updates

### Components

**Core Components:**
- `CodePreview` - Syntax-highlighted code display
- `GatewayStatus` - Real-time gateway health indicator
- `TagsInput` - Multi-tag input with autocomplete
- `UrlPreview` - Rich link preview generation

## 🔐 Authentication

The application supports two authentication modes:

### Development Mode (Default)
```elixir
# config/dev.exs
config :ui_web, auth_enabled: false
```

### OIDC Mode (Production)
```elixir
# config/prod.exs
config :ui_web,
  auth_enabled: true,
  oidc_discovery_url: System.get_env("OIDC_DISCOVERY_URL")
```

## 📈 Observability

### Telemetry

Telemetry events are emitted for:
- HTTP requests/responses
- Gateway client operations
- LiveView lifecycle
- Custom business metrics

### Metrics Endpoint

Prometheus-compatible metrics available at `/metrics` (when enabled).

### Health Check

```bash
curl http://localhost:4000/health
```

## 🚢 Deployment

### Docker

```bash
# Build image
docker build -t beamline-ui-web .

# Run container
docker run -p 4000:4000 \
  -e GATEWAY_BASE_URL=http://gateway:8080 \
  -e SECRET_KEY_BASE=your-secret \
  beamline-ui-web
```

### Production Release

```bash
# Build production release
MIX_ENV=prod mix release

# Run release
_build/prod/rel/ui_web/bin/ui_web start
```

See [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html) for more options.

## 🔗 Integration

### Gateway Client

The application integrates with the C-Gateway via HTTP:

```elixir
# Publish a message
UiWeb.Services.MessagesClient.publish_message(
  topic: "workflow.events",
  payload: %{event: "started", flow_id: "123"}
)

# Get extensions
UiWeb.Services.ExtensionsClient.list_extensions()
```

### Real-time Updates

SSE integration for real-time event streaming:

```elixir
# Subscribe to events
UiWeb.Realtime.EventSubscriber.subscribe(["workflow.events"])
```

## 📚 Documentation

- **[AGENTS.md](AGENTS.md)** - AI agent specifications
- **[Development Docs](docs/dev/)** - Detailed development documentation
- **[E2E Testing](test/e2e/README.md)** - E2E test documentation
- **[API Spec](lib/ui_web/contracts/api_spec.ex)** - Gateway API specification

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

```bash
# Format code
mix format

# Run linter (if configured)
mix credo

# Pre-commit checks
mix precommit
```

## 🐛 Troubleshooting

### Assets not loading

```bash
cd assets && npm install
mix assets.build
```

### Port already in use

```bash
# Change port in config/dev.exs or use env var
PORT=4001 mix phx.server
```

### Gateway connection errors

Check that the C-Gateway is running and accessible:

```bash
curl http://localhost:8080/health
```

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- **[Beamline Platform](https://github.com/YOUR_ORG/beamline)** - Main platform repository
- **[C-Gateway](https://github.com/rustkas/beamline-c-gateway)** - High-performance C gateway
- **[CAF Components](https://github.com/rustkas/beamline-caf)** - C++ Actor Framework components
- **[Router](../otp/router)** - Erlang/OTP routing and orchestration

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/rustkas/beamline-ui-web/issues)
- **Documentation**: [docs/](docs/)
- **Phoenix Guides**: [hexdocs.pm/phoenix](https://hexdocs.pm/phoenix/overview.html)

---

**Built with ❤️ using Phoenix LiveView**
