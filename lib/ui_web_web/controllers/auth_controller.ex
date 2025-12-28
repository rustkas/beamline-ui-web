defmodule UiWebWeb.AuthController do
  use UiWebWeb, :controller
  plug Ueberauth
  alias UiWeb.Auth.Guardian

  def login(conn, _params), do: render(conn, :login)

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{id: auth.uid, email: auth.info.email, name: auth.info.name}

    conn
    |> Guardian.Plug.sign_in(user_params)
    |> put_flash(:info, "Successfully authenticated")
    |> redirect(to: ~p"/app/tenant_dev/dashboard")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate")
    |> redirect(to: ~p"/login")
  end

  def logout(conn, _params) do
    conn
    |> Guardian.Plug.sign_out()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: ~p"/login")
  end
end
