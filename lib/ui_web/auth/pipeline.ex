defmodule UiWeb.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :ui_web,
    module: UiWeb.Auth.Guardian,
    error_handler: UiWeb.Auth.ErrorHandler

  plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  plug Guardian.Plug.LoadResource, allow_blank: true
end
