defmodule UiWeb.Test.Config do
  @moduledoc """
  Centralized test configuration and timeouts.
  
  Provides consistent timeout values and configuration
  for all test helpers and integration tests.
  """
  
  def gateway_timeout, do: 5_000
  def sse_timeout, do: 10_000
  def pubsub_timeout, do: 3_000
  def eventually_timeout, do: 5_000
  def eventually_interval, do: 100
  
  def gateway_url do
    System.get_env("GATEWAY_URL") || "http://localhost:8081"
  end
  
  def gateway_timeout_ms do
    String.to_integer(System.get_env("GATEWAY_TIMEOUT") || "5000")
  end
end

