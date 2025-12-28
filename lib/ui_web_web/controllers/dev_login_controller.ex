defmodule UiWebWeb.DevLoginController do
  @moduledoc """
  Development login endpoint for E2E tests.
  
  This controller provides a simple way to authenticate in E2E tests
  without requiring OIDC or real authentication flow.
  
  **Only available in test/dev environments.**
  
  ## Usage
  
      GET /dev-login?user=test_user&tenant=test_tenant
  
  This will:
  1. Create a test user with provided params
  2. Sign in via Guardian
  3. Redirect to /app/dashboard
  
  ## Security
  
  This endpoint is only enabled when:
  - `Mix.env() == :test` OR
  - `Application.get_env(:ui_web, :dev_login_enabled, false) == true`
  """
  
  use UiWebWeb, :controller
  
  alias UiWeb.Auth.Guardian
  
  def login(conn, params) do
    # Only allow in test or when explicitly enabled
    unless allowed?() do
      conn
      |> put_status(:not_found)
      |> text("Not found")
    else
      user_id = Map.get(params, "user", "test_user")
      tenant_id = Map.get(params, "tenant", "test_tenant")
      
      # Create test user
      user = %{
        id: user_id,
        tenant_id: tenant_id,
        email: "#{user_id}@test.local",
        name: "Test User"
      }
      
      # Sign in via Guardian
      conn
      |> Guardian.Plug.sign_in(user)
      |> put_flash(:info, "Logged in as #{user_id}")
      |> redirect(to: ~p"/app/#{tenant_id}/dashboard")
    end
  end
  
  defp allowed? do
    Mix.env() == :test || Application.get_env(:ui_web, :dev_login_enabled, false)
  end
end

