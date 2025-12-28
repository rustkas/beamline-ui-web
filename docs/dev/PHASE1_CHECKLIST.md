# Phase 1 Checklist — UI Web Setup

## Required Steps
- [ ] Install Elixir/Erlang (`elixir --version`)
- [ ] Install Phoenix (`mix phx.new --version`)
- [ ] Create project (`apps/ui_web`) with `mix phx.new ui_web --no-ecto --live`
- [ ] `mix deps.get`, `cd assets && npm install`
- [ ] Generate secrets: `mix phx.gen.secret`, `mix guardian.gen.secret` → update `.env`
- [ ] `source .env`
- [ ] Update layouts and create Dashboard LiveView
- [ ] Run server: `mix phx.server`
- [ ] Verify pages: `/`, `/login`, `/dev/dashboard`

## Common Issues & Solutions
- `mix` not found → install Elixir per docs.
- Phoenix generator not found → `mix local.hex && mix local.rebar && mix archive.install hex phx_new`.
- Missing `SECRET_KEY_BASE` → run `mix phx.gen.secret` and update `.env`.
- CSS not applied → ensure Tailwind built and assets installed in `assets/`.

## References
- See `docs/archive/dev/PHASE1_UI_WEB_PROJECT_SETUP.md` for full step-by-step.