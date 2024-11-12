# defmodule LovebombWeb.AuthErrorHandler do
#   use LovebombWeb, :controller

#   @behaviour Guardian.Plug.ErrorHandler

#   @impl Guardian.Plug.ErrorHandler
#   def auth_error(conn, {type, _reason}, _opts) do
#     conn
#     |> put_status(401)
#     |> put_view(json: LovebombWeb.ErrorJSON)
#     |> render(:"401", %{error: to_string(type)})
#   end
# end
