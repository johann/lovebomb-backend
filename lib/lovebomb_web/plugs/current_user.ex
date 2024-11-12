defmodule LovebombWeb.Plugs.CurrentUser do
  @moduledoc """
  Plug to load the current user into conn assigns.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    user = Guardian.Plug.current_resource(conn)
    Plug.Conn.assign(conn, :current_user, user)
  end
end
