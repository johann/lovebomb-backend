# lib/lovebomb_web/plugs/ensure_admin.ex
defmodule LovebombWeb.Plugs.EnsureAdmin do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns.current_user

    if user && user.admin do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> put_view(json: LovebombWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    end
  end
end
