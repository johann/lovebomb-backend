defmodule LovebombWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :lovebomb,
    module: Lovebomb.Guardian,
    error_handler: LovebombWeb.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
