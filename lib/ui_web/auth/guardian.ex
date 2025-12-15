defmodule UiWeb.Auth.Guardian do
  use Guardian, otp_app: :ui_web

  def subject_for_token(%{id: id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(_, _), do: {:error, :no_id_provided}

  def resource_from_claims(%{"sub" => id}), do: {:ok, %{id: id, email: "user@example.com"}}
  def resource_from_claims(_), do: {:error, :no_claims_sub}
end
