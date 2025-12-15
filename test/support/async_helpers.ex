defmodule UiWeb.Test.AsyncHelpers do
  @moduledoc """
  Helpers for testing asynchronous operations.
  
  Provides utilities for retrying assertions, waiting for conditions,
  and handling race conditions in tests.
  """
  
  @doc """
  Retry an assertion until it passes or timeout.
  
  ## Examples
  
      eventually(fn ->
        {:ok, messages} = GatewayClient.list_messages()
        assert length(messages["items"]) > 0
      end, timeout: 5_000, interval: 100)
  """
  def eventually(assertion_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    interval = Keyword.get(opts, :interval, 100)
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
          # Final attempt - let it raise
          reraise error, __STACKTRACE__
        end
    end
  end
  
  @doc """
  Wait for a condition to be true.
  
  ## Examples
  
      wait_until(fn ->
        {:ok, health} = GatewayClient.fetch_health()
        health["status"] == "ok"
      end, timeout: 10_000)
  """
  def wait_until(condition_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    interval = Keyword.get(opts, :interval, 100)
    deadline = System.monotonic_time(:millisecond) + timeout
    
    do_wait_until(condition_fn, deadline, interval)
  end
  
  defp do_wait_until(condition_fn, deadline, interval) do
    if condition_fn.() do
      :ok
    else
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(interval)
        do_wait_until(condition_fn, deadline, interval)
      else
        raise "Timeout waiting for condition"
      end
    end
  end
  

  @doc """
  Wait for PubSub message with timeout.
  
  ## Examples
  
      assert_receive_pubsub("messages", {:message_created, _}, timeout: 5_000)
  """
  defmacro assert_receive_pubsub(topic, pattern, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    
    quote do
      Phoenix.PubSub.subscribe(UiWeb.PubSub, unquote(topic))
      
      assert_receive %Phoenix.Socket.Broadcast{
        topic: unquote(topic),
        event: _,
        payload: unquote(pattern)
      }, unquote(timeout)
    end
  end
end

