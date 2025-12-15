# Assets Management Guide

## Overview

This Phoenix application uses **esbuild** for JavaScript and **Tailwind CSS** for styling.

## Development

### Automatic Asset Building

When you run `mix phx.server`, assets are automatically built and watched:

```bash
mix phx.server
```

**What happens:**
- ✅ Tailwind CSS watches `assets/css/app.css` and templates
- ✅ Esbuild watches `assets/js/app.js`
- ✅ Changes trigger automatic rebuild
- ✅ LiveReload refreshes browser

### Manual Build

```bash
# Build assets once
mix assets.build

# Setup tools (install esbuild & tailwind)
mix assets.setup
```

## Production

### Build for Production

```bash
# Build minified assets with digest
mix assets.deploy

# Then compile release
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
```

**What `mix assets.deploy` does:**
1. Runs Tailwind with `--minify`
2. Runs Esbuild with `--minify`
3. Generates `cache_manifest.json` via `phx.digest`

## Core Pages (require Gateway)

UI depends on the Gateway API for data:

- `/app/dashboard` → GET `${GATEWAY_URL}/_health`
- `/app/messages` → GET/POST `${GATEWAY_URL}/api/v1/messages`
- `/app/policies` → GET/PUT/DELETE `${GATEWAY_URL}/api/v1/policies/*`
- `/app/extensions` → GET `${GATEWAY_URL}/api/v1/registry/blocks[/:type]`

Set `GATEWAY_URL` (dev default: `http://localhost:8080`).

Verify:

```bash
curl -s ${GATEWAY_URL:-http://localhost:8080}/_health | jq .
```

### Environment Variables

Production requires:
- `SECRET_KEY_BASE` - Generate with `mix phx.gen.secret`
- `PHX_HOST` - Your domain (default: example.com)
- `PORT` - HTTP port (default: 4000)

## Troubleshooting

### Styles not applying

**Problem:** White text on white background

**Solution:** Check Tailwind config paths in `assets/tailwind.config.js`:

```javascript
content: [
  "./js/**/*.js",
  "../lib/*_web.ex",
  "../lib/*_web/**/*.*ex"  // Must include ui_web_web/
]
```

### Assets not found in production

**Problem:** 404 errors for CSS/JS files

**Solution:** Run `mix assets.deploy` before building release

### Watchers not starting

**Problem:** Changes don't trigger rebuild

**Solution:** Check `config/dev.exs` watchers configuration:

```elixir
watchers: [
  esbuild: {Esbuild, :install_and_run, [:ui_web, ~w(--sourcemap=inline --watch)]},
  tailwind: {Tailwind, :install_and_run, [:ui_web, ~w(--watch)]}
]
```

## File Structure

```
assets/
├── css/
│   └── app.css          # Tailwind imports & custom styles
├── js/
│   └── app.js           # JavaScript entry point
└── tailwind.config.js   # Tailwind configuration

priv/static/assets/
├── app.css              # Compiled CSS (dev: 23KB, prod: minified)
└── app.js               # Compiled JS
```

## Mix Aliases

| Command | Description |
|---------|-------------|
| `mix setup` | Install deps + setup assets + build |
| `mix assets.setup` | Install esbuild & tailwind binaries |
| `mix assets.build` | Build assets for development |
| `mix assets.deploy` | Build & minify for production |

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Setup assets
  run: mix assets.setup

- name: Build assets
  run: mix assets.deploy

- name: Build release
  run: MIX_ENV=prod mix release
```

### Docker Example

```dockerfile
# Install assets tools
RUN mix assets.setup

# Build production assets
RUN mix assets.deploy

# Compile release
RUN MIX_ENV=prod mix compile
```

## Performance

**Development:**
- CSS: ~23KB uncompressed
- JS: ~532 bytes
- Rebuild time: ~500-1300ms

**Production (after minify + gzip):**
- CSS: ~5-8KB
- JS: ~200 bytes
- Includes cache busting via digest
