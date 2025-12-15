defmodule UiWeb.Test.Retry do
  @moduledoc """
  Helper for retrying flaky tests.
  
  Provides a simple retry mechanism for tests that may occasionally fail
  due to timing issues, async operations, or external dependencies.
  
  ## Usage
  
      @tag retry: 3
      test "flaky test" do
        UiWeb.Test.Retry.retry(3, fn ->
          assert some_condition()
        end)
      end
      
  Or use the helper in setup:
  
      setup %{retry: retry_count} do
        # retry_count comes from @tag retry: N
        # ...
      end
  """
  
  @doc """
  Retry a block of code up to `times` attempts.
  
  ## Examples
  
      Retry.retry(3, fn ->
        assert_html(view, "expected_text", timeout: 1000)
      end)
  """
  def retry(times, fun) when is_integer(times) and times > 0 and is_function(fun, 0) do
    do_retry(times, fun, 1)
  end
  
  defp do_retry(max_times, fun, attempt) when attempt <= max_times do
    try do
      fun.()
    rescue
      error ->
        if attempt < max_times do
          # Wait a bit before retry (exponential backoff)
          delay = :math.pow(2, attempt - 1) * 100 |> round()
          Process.sleep(delay)
          do_retry(max_times, fun, attempt + 1)
        else
          # Last attempt failed - raise the error
          reraise error, __STACKTRACE__
        end
    catch
      kind, error ->
        if attempt < max_times do
          delay = :math.pow(2, attempt - 1) * 100 |> round()
          Process.sleep(delay)
          do_retry(max_times, fun, attempt + 1)
        else
          :erlang.raise(kind, error, __STACKTRACE__)
        end
    end
  end
  
  @doc """
  Retry with custom delay between attempts.
  
  ## Examples
  
      Retry.retry(3, 200, fn ->
        assert_html(view, "expected_text")
      end)
  """
  def retry(times, delay_ms, fun) when is_integer(times) and times > 0 and is_function(fun, 0) do
    do_retry_with_delay(times, delay_ms, fun, 1)
  end
  
  defp do_retry_with_delay(max_times, delay_ms, fun, attempt) when attempt <= max_times do
    try do
      fun.()
    rescue
      error ->
        if attempt < max_times do
          Process.sleep(delay_ms)
          do_retry_with_delay(max_times, delay_ms, fun, attempt + 1)
        else
          reraise error, __STACKTRACE__
        end
    catch
      kind, error ->
        if attempt < max_times do
          Process.sleep(delay_ms)
          do_retry_with_delay(max_times, delay_ms, fun, attempt + 1)
        else
          :erlang.raise(kind, error, __STACKTRACE__)
        end
    end
  end
end

