# LiveComponent notify_parent Pattern

**File:** `apps/ui_web/lib/ui_web_web/components/tags_input.ex`

## Key Principle

**LiveComponent does NOT have a separate process.** Both LiveView and all its LiveComponents live in **the same process**.

### Consequences

- Inside LiveComponent, `self()` is the **LiveView PID**
- Message `send(self(), msg)` from component goes to LiveView's `handle_info/2`
- No `socket.view.pid` or `parent_pid` needed

---

## Canonical Pattern

### In Component

```elixir
defp notify_parent(socket, tags) do
  # In LiveComponent, self() is the LiveView process (same process)
  # Use canonical pattern: send(self(), {__MODULE__, msg})
  send(self(), {__MODULE__, {:tags_updated, socket.assigns.id, tags}})
end
```

**Key points:**
- Use `send(self(), ...)` - no need for `socket.view.pid`
- Include `__MODULE__` in message tuple for explicit routing
- Message format: `{__MODULE__, {:tags_updated, id, tags}}`

### In Parent LiveView

```elixir
def handle_info({UiWebWeb.Components.TagsInput, {:tags_updated, _id, tags}}, socket) do
  # Update field.value when component notifies parent
  # Match canonical pattern: {__MODULE__, {:tags_updated, id, tags}}
  updated_field = %{socket.assigns.field | value: tags}
  {:noreply, assign(socket, :field, updated_field)}
end
```

**Key points:**
- Pattern must **exactly match** the message format from component
- If component sends `{__MODULE__, msg}`, parent must match `{Module, msg}`
- If component sends just `msg`, parent must match `msg` (without module wrapper)

---

## Testing Pattern

### Integration Tests (Recommended)

Use `live_isolated/3` to test component + LiveView together:

```elixir
defp setup_component(conn, assigns \\ []) do
  field = Keyword.get(assigns, :field, %{name: "tags", value: []})
  suggestions = Keyword.get(assigns, :suggestions, [])
  max_tags = Keyword.get(assigns, :max_tags, 20)

  # Use live_isolated to avoid router dependency
  live_isolated(conn, TestTagsInputLiveView,
    session: %{
      "field" => field,
      "suggestions" => suggestions,
      "max_tags" => max_tags
    }
  )
end

test "removes tag on remove button click", %{conn: conn} do
  {:ok, view, html} =
    setup_component(conn,
      field: %{name: "tags", value: ["llm", "streaming"]}
    )

  assert html =~ "llm"
  assert html =~ "streaming"

  # Click remove button
  view
  |> element("button[phx-click='remove_tag'][phx-value-tag='llm']")
  |> render_click()

  # Wait for parent LiveView to process {:tags_updated} message
  html = render(view)

  refute html =~ "llm"
  assert html =~ "streaming"
  assert html =~ "(1/"
end
```

**Why this works:**
- `live_isolated/3` creates a real LiveView process
- Component executes in the same process
- `send(self(), ...)` from component goes to LiveView's `handle_info/2`
- Test verifies the full integration

### Unit Tests (Alternative)

If testing component directly with `render_component/2`:

```elixir
html =
  render_component(&UiWebWeb.Components.TagsInput.render/1,
    id: "tags-input",
    field: %{name: "tags", value: ["llm", "streaming"]},
    max_tags: 20
  )

# Component executes in test process, self() = test PID
# Can use assert_receive if needed:
assert_receive {UiWebWeb.Components.TagsInput, {:tags_updated, "tags-input", ["streaming"]}}
```

**Note:** In this case, message goes to test process, not LiveView. Use this pattern only for component-only tests, not integration tests.

---

## Common Mistakes

### ❌ Wrong: Using `socket.view.pid`

```elixir
defp notify_parent(socket, tags) do
  case socket do
    %{view: %{pid: pid}} when is_pid(pid) ->
      send(pid, {:tags_updated, socket.assigns.id, tags})
    _ ->
      send(self(), {:tags_updated, socket.assigns.id, tags})
  end
end
```

**Why wrong:**
- `socket.view.pid` is internal implementation detail
- Not needed - `self()` already points to LiveView process
- Adds unnecessary complexity

### ❌ Wrong: Using `parent_pid` in assigns

```elixir
defp notify_parent(socket, tags) do
  parent_pid = socket.assigns.parent_pid
  send(parent_pid, {:tags_updated, socket.assigns.id, tags})
end
```

**Why wrong:**
- Breaks idiomatic LiveView model
- Component shouldn't need to know parent PID
- They're in the same process anyway

### ❌ Wrong: Mismatched message format

```elixir
# Component sends:
send(self(), {__MODULE__, {:tags_updated, id, tags}})

# But parent expects:
def handle_info({:tags_updated, _id, tags}, socket) do
  # This will NEVER match!
end
```

**Why wrong:**
- Message format must **exactly match** pattern in `handle_info/2`
- If component sends `{Module, msg}`, parent must match `{Module, msg}`
- If component sends `msg`, parent must match `msg`

---

## Current Implementation Status

✅ **Correctly implemented in `tags_input.ex`:**

```elixir
defp notify_parent(socket, tags) do
  # In LiveComponent, self() is the LiveView process (same process)
  # Use canonical pattern: send(self(), {__MODULE__, msg})
  send(self(), {__MODULE__, {:tags_updated, socket.assigns.id, tags}})
end
```

✅ **Correctly handled in `TestTagsInputLiveView`:**

```elixir
def handle_info({UiWebWeb.Components.TagsInput, {:tags_updated, _id, tags}}, socket) do
  # Update field.value when component notifies parent
  # Match canonical pattern: {__MODULE__, {:tags_updated, id, tags}}
  updated_field = %{socket.assigns.field | value: tags}
  {:noreply, assign(socket, :field, updated_field)}
end
```

✅ **Tests use `live_isolated/3` correctly**

✅ **All tests passing (19 tests, 0 failures)**

---

## References

- Phoenix LiveView Documentation: [LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html)
- Component implementation: `apps/ui_web/lib/ui_web_web/components/tags_input.ex`
- Test implementation: `apps/ui_web/test/ui_web_web/components/tags_input_test.exs`

