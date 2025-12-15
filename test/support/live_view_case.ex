defmodule UiWebWeb.LiveViewCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a LiveView connection.

  Such tests rely on `Phoenix.LiveViewTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import UiWebWeb.ConnCase
      import UiWebWeb.LiveViewCase
      import UiWeb.TestHelpers

      # The default endpoint for testing
      @endpoint UiWebWeb.Endpoint

      use UiWebWeb, :verified_routes
    end
  end

  setup tags do
    # Start Mock Gateway if needed
    if tags[:integration] || tags[:live_view] do
      # Mock Gateway should already be started in test_helper.exs
      # But we ensure it's available
      gateway_url = Application.get_env(:ui_web, :gateway) |> Keyword.get(:url, "http://localhost:8081")
      
      # Wait for mock gateway to be ready
      wait_for_gateway(gateway_url, 5_000)
    end

    # Build authenticated connection for LiveView tests
    # Create a mock user and sign in with Guardian
    conn = Phoenix.ConnTest.build_conn()
    
    # Create a test user
    test_user = %{id: "test_user_#{System.unique_integer([:positive])}", tenant_id: "test_tenant"}
    
    # Sign in with Guardian - encode token and set it properly
    case UiWeb.Auth.Guardian.encode_and_sign(test_user) do
      {:ok, token, claims} ->
        # Set token and resource in Guardian plugs to bypass EnsureAuthenticated check
        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
          |> Plug.Test.init_test_session(%{})
          |> Plug.Conn.put_session("guardian_default_token", token)
          |> Guardian.Plug.put_current_token(token)
          |> Guardian.Plug.put_current_resource(test_user)
          |> Guardian.Plug.put_current_claims(claims)
          |> Plug.Conn.assign(:current_user, test_user)
        
        {:ok, conn: conn}
      
      _ ->
        # Fallback: use unauthenticated conn (tests will handle 401)
        {:ok, conn: conn}
    end
  end

  defp wait_for_gateway(url, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    
    case Req.get("#{url}/health", receive_timeout: 2_000) do
      {:ok, %{status: 200}} ->
        :ok
      
      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(100)
          wait_for_gateway(url, timeout - 100)
        else
          # Don't fail tests if mock gateway isn't available
          # Tests will handle errors gracefully
          :ok
        end
    end
  rescue
    _ -> :ok
  end
end

