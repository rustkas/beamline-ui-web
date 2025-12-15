defmodule UiWeb.Test.MockGatewayServer do
  @moduledoc """
  Helper module to start/stop Mock Gateway server for tests.
  """

  @default_port 8082

  def start(opts \\ []) do
    port = Keyword.get(opts, :port, @default_port)

    case Plug.Cowboy.http(UiWeb.Test.MockGateway, [], port: port) do
      {:ok, pid} ->
        # Wait for server to be ready
        wait_for_server(port, 5_000)
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      error ->
        error
    end
  end

  def stop(pid) when is_pid(pid) do
    try do
      Plug.Cowboy.shutdown(pid)
    catch
      :exit, {:noproc, _} -> :ok
    end
  end

  def stop(_), do: :ok

  defp wait_for_server(port, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    url = ~c"http://localhost:" ++ Integer.to_charlist(port) ++ ~c"/health"
    case :httpc.request(:get, {url, []}, [], []) do
      {:ok, {{_, 200, _}, _, _}} ->
        :ok

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(100)
          wait_for_server(port, timeout - 100)
        else
          raise "Mock Gateway server failed to start on port #{port}"
        end
    end
  rescue
    _ ->
      # HTTP client may not be available, just wait a bit
      Process.sleep(500)
      :ok
  end
end
