defmodule UiWeb.TestHelpers do
  @moduledoc """
  Global test helpers for UI-Web tests.
  
  Provides convenient assertion helpers for LiveView tests,
  eventually pattern for async operations, and other common utilities.
  """
  
  require ExUnit.Assertions
  
  @doc """
  Retry an assertion until it passes or timeout.
  
  This is a simplified version of `eventually` that's globally available
  in all test files that use `LiveViewCase`.
  
  ## Examples
  
      eventually(fn ->
        html = render(view)
        assert html =~ "msg_001"
      end, timeout: 1000, interval: 50)
  """
  def eventually(assertion_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    interval = Keyword.get(opts, :interval, 50)
    deadline = System.monotonic_time(:millisecond) + timeout
    
    do_eventually(assertion_fn, deadline, interval)
  end
  
  defp do_eventually(assertion_fn, deadline, interval) do
    try do
      assertion_fn.()
    rescue
      error ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(interval)
          do_eventually(assertion_fn, deadline, interval)
        else
          # Final attempt - let it raise with original error
          reraise error, __STACKTRACE__
        end
    end
  end
  
  @doc """
  Assert that rendered HTML contains expected text.
  
  Waits for the text to appear using `eventually` pattern.
  
  ## Examples
  
      assert_html(view, "msg_001")
      assert_html(view, ~r/Deleted|deleted/)
  """
  def assert_html(view, expected, opts \\ []) do
    eventually(fn ->
      html = Phoenix.LiveViewTest.render(view)
      matches? = case expected do
        %Regex{} = regex -> Regex.match?(regex, html)
        text when is_binary(text) -> String.contains?(html, text)
      end
      ExUnit.Assertions.assert(matches?, "Expected to find #{inspect(expected)} in render, but it was not found")
    end, opts)
  end
  
  @doc """
  Assert that rendered HTML does NOT contain expected text.
  
  Waits for the text to disappear using `eventually` pattern.
  
  ## Examples
  
      refute_html(view, "msg_001")
      refute_html(view, ~r/error/i)
  """
  def refute_html(view, unexpected, opts \\ []) do
    eventually(fn ->
      html = Phoenix.LiveViewTest.render(view)
      matches? = case unexpected do
        %Regex{} = regex -> Regex.match?(regex, html)
        text when is_binary(text) -> String.contains?(html, text)
      end
      ExUnit.Assertions.refute(matches?, "Expected NOT to find #{inspect(unexpected)} in render, but it was found")
    end, opts)
  end
  
  @doc """
  Assert that an element exists in the view.
  
  ## Examples
  
      assert_element(view, "button[phx-click='delete']")
      assert_element(view, "input[type='checkbox']", "msg_001")
  """
  def assert_element(view, selector, text \\ nil) do
    ExUnit.Assertions.assert(Phoenix.LiveViewTest.has_element?(view, selector, text))
  end
  
  @doc """
  Assert that an element does NOT exist in the view.
  
  ## Examples
  
      refute_element(view, "button[phx-click='delete']")
      refute_element(view, "input[type='checkbox']", "msg_001")
  """
  def refute_element(view, selector, text \\ nil) do
    ExUnit.Assertions.refute(Phoenix.LiveViewTest.has_element?(view, selector, text))
  end
end

