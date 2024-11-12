defmodule LovebombWeb.AuthErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    body = Jason.encode!(%{
      error: %{
        code: to_string(type),
        message: error_message(type)
      }
    })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, body)
  end

  defp error_message(:invalid_token), do: "Invalid token"
  defp error_message(:unauthorized), do: "Unauthorized access"
  defp error_message(:unauthenticated), do: "Not authenticated"
  defp error_message(:token_expired), do: "Token has expired"
  defp error_message(_), do: "Authentication error"
end
