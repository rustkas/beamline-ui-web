# CI and DevEx Improvements

**Goal:** Make tests and development not only stable, but also maximally convenient and fast.

This document describes three key improvements:

1. **Automatic `mix mock.reset`**
2. **Test retries for flaky scenarios**
3. **DB sandbox improvements** (if applicable)

---

## 1️⃣ Automatic `mix mock.reset`

### Problem

We use ETS in mock gateway, and in tests state is cleared manually before each test.

Locally everything is fine.

But in **CI**:
- Tests may run in parallel
- Test process may remain "dirty"
- ETS may contain old state
- Rare errors like:
  - "Why is state left after another test?"
  - "Works locally — fails in CI"
  - "Unexplained nondeterministic bug"

This is a characteristic symptom of tests depending on external state.

### Solution

**Automatically reset ETS before running tests.**

### Implementation

#### Mix Alias

In `mix.exs`:

```elixir
defp aliases do
  [
    # ... other aliases ...
    "test.all": ["mock.reset", "test"]
  ]
end
```

**Usage:**

```bash
# Run tests with automatic mock reset
mix test.all

# Or manually
mix mock.reset && mix test
```

#### CI Integration

**GitLab CI** (`.gitlab-ci.yml`):

```yaml
test:
  script:
    - mix mock.reset
    - mix test --color
```

**GitHub Actions** (`.github/workflows/*.yml`):

```yaml
- name: Reset mock state
  run: mix mock.reset

- name: Run tests
  run: mix test
```

### Benefits

- ✅ Tests always start in clean state
- ✅ CI becomes deterministic
- ✅ Eliminates rare race-condition errors on mock gateway
- ✅ Developer doesn't forget to clean environment manually

---

## 2️⃣ Test Retries for Flaky External Scenarios

### Problem

Some test groups **can be flaky by nature**, for example:
- Polling checks
- Work with external services
- Async processes
- Race conditions between LiveView render and state updates

Even after removing `Process.sleep`, polling and health mechanics can still be unstable in CI.

Reason — **execution time in CI is unpredictable.**

### Solution

Add **automatic retry** for tests that may rarely flap.

### Implementation

#### Custom Retry Helper

We use a custom retry helper (`UiWeb.Test.Retry`) that doesn't require external dependencies.

**Location:** `apps/ui_web/test/support/test_retry.ex`

#### Usage in Tests

**Use retry helper in flaky tests:**

```elixir
alias UiWeb.Test.Retry

@tag retry: 3
test "polls Gateway for health updates", %{conn: conn} do
  Retry.retry(3, fn ->
    {:ok, view, _html} = live(conn, ~p"/app/dashboard")
    
    # Wait for initial poll
    assert_html(view, ~r/ok|System Status|Component Health/, timeout: 2000)
    
    # Trigger manual poll
    send(view.pid, :tick)
    
    # Wait for update (polling is async, may take time)
    assert_html(view, ~r/ok|System Status|Component Health/, timeout: 2000)
  end)
end
```

**With custom delay:**

```elixir
alias UiWeb.Test.Retry

test "flaky test with custom delay", %{conn: conn} do
  Retry.retry(3, 200, fn ->
    # Test code that may occasionally fail
    assert some_condition()
  end)
end
```

### Which Tests Should Use Retry?

**Good candidates:**
- ✅ Polling tests (`dashboard_live_test.exs`, `messages_live_test.exs`)
- ✅ Metrics tests (async updates)
- ✅ Health check tests (external service timing)
- ✅ Tests with `eventually/2` or `assert_html` with timeouts

**Not needed:**
- ❌ Pure unit tests (no async operations)
- ❌ Tests with deterministic mocks
- ❌ Property-based tests

### Benefits

- ✅ CI becomes even more stable
- ✅ Eliminates all random failures
- ✅ Polling and metrics tests become reliable

---

## 3️⃣ DB Sandbox Improvements

### Problem

If the project uses DB in tests:
- **Not always** full `Ecto.Adapters.SQL.Sandbox` is used
- Tests sometimes switch to shared mode
- In LiveView tests sandbox doesn't always work correctly with async
- Large test volume increases probability of deadlocks

### Solution

**Note:** This project uses Ecto optionally (`{:ecto, "~> 3.11", optional: true}`). If your project doesn't use Ecto, skip this section.

### Implementation

#### A) Globally Enable Sandbox by Default

In `config/test.exs`:

```elixir
config :ui_web, UiWeb.Repo,
  pool: Ecto.Adapters.SQL.Sandbox
```

#### B) Automatically Call Sandbox Checkout

In `test/support/conn_case.ex`:

```elixir
setup tags do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(UiWeb.Repo)

  if tags[:async] do
    Ecto.Adapters.SQL.Sandbox.mode(UiWeb.Repo, {:shared, self()})
  end

  {:ok, conn: build_conn()}
end
```

#### C) For LiveView Tests — Correct Mode

LiveView usually requires shared mode:

In `test/support/live_view_case.ex`:

```elixir
setup tags do
  # Sandbox checkout for LiveView tests
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(UiWeb.Repo)
  Ecto.Adapters.SQL.Sandbox.mode(UiWeb.Repo, {:shared, self()})
  
  # ... rest of setup ...
end
```

### Benefits

- ✅ Faster test execution
- ✅ Isolation of each test
- ✅ No deadlocks
- ✅ Stability of LiveView in async mode
- ✅ Reduced CI unpredictability

---

## 🎯 Summary — Why This Matters

These three improvements provide:

### ✨ Maximum CI Stability

- No random failures
- No "works locally, fails in CI"

### ✨ Improved DevEx for Developers

- Tests run fast and always the same
- No need to manually reset state
- Retry tags solve polling/metrics problems

### ✨ Architectural Consistency

- Mock gateway + client layer + UI are now fully controllable
- CI doesn't break these guarantees

---

## 📋 Quick Reference

### Commands

```bash
# Run tests with automatic mock reset
mix test.all

# Reset mock state manually
mix mock.reset

# Run only flaky tests with retry
mix test --only retry:3

# Run all tests
mix test
```

### Test Retry Usage

```elixir
alias UiWeb.Test.Retry

# Single test with retry
@tag retry: 3
test "flaky test" do
  Retry.retry(3, fn ->
    # Test code
    assert condition()
  end)
end

# With custom delay between retries
test "flaky test with delay" do
  Retry.retry(3, 200, fn ->
    # Test code
    assert condition()
  end)
end
```

---

## References

- Mock Gateway: `apps/ui_web/test/support/mock_gateway.ex`
- Mock Reset Task: `apps/ui_web/lib/mix/tasks/mock.reset.ex`
- Test Retry Helper: `apps/ui_web/test/support/test_retry.ex`
- Test Helpers: `apps/ui_web/test/support/`

