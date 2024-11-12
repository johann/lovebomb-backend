defmodule LovebombWeb.PartnershipController do
  use LovebombWeb, :controller
  alias Lovebomb.Accounts

  action_fallback LovebombWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    partnerships = Accounts.list_partnerships(user.id)
    render(conn, :index, partnerships: partnerships)
  end

  def create(conn, %{"partner_id" => partner_id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, partnership} <- Accounts.create_partnership(%{
      user_id: user.id,
      partner_id: partner_id,
      status: :pending
    }) do
      conn
      |> put_status(:created)
      |> render(:show, partnership: partnership)
    end
  end

  def update(conn, %{"id" => partner_id, "status" => status}) do
    user = Guardian.Plug.current_resource(conn)

    with partnership <- Accounts.get_partnership(user.id, partner_id),
         {:ok, updated} <- Accounts.update_partnership_status(partnership, status) do
      render(conn, :show, partnership: updated)
    end
  end

  def delete(conn, %{"id" => partner_id}) do
    user = Guardian.Plug.current_resource(conn)

    with :ok <- Accounts.delete_partnership(user.id, partner_id) do
      send_resp(conn, :no_content, "")
    end
  end

  def stats(conn, %{"id" => partner_id}) do
    user = Guardian.Plug.current_resource(conn)
    stats = Accounts.get_partnership_stats(user.id, partner_id)
    render(conn, :stats, stats: stats)
  end

  def achievements(conn, %{"partnership_id" => id}) do
    achievements = Accounts.get_partnership_achievements(id)
    render(conn, :achievements, achievements: achievements)
  end
end
