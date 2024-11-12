defmodule LovebombWeb.PartnershipInteractionController do
  use LovebombWeb, :controller
  alias Lovebomb.Accounts

  action_fallback LovebombWeb.FallbackController

  def index(conn, %{"partnership_id" => partnership_id} = params) do
    opts = [
      limit: Map.get(params, "limit", "20") |> String.to_integer(),
      offset: Map.get(params, "offset", "0") |> String.to_integer()
    ]

    interactions = Accounts.list_partnership_interactions(partnership_id, opts)
    render(conn, :index, interactions: interactions)
  end

  def create(conn, %{"partnership_id" => partnership_id} = params) do
    with {:ok, interaction} <- Accounts.record_interaction(partnership_id, params) do
      conn
      |> put_status(:created)
      |> render(:show, interaction: interaction)
    end
  end
end
