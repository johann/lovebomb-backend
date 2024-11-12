defmodule LovebombWeb.PartnershipJSON do
  alias Lovebomb.Accounts.Partnership

  def index(%{partnerships: partnerships}) do
    %{data: for(partnership <- partnerships, do: data(partnership))}
  end

  def show(%{partnership: partnership}) do
    %{data: data(partnership)}
  end

  def stats(%{stats: stats}), do: %{data: stats}

  defp data(%Partnership{} = partnership) do
    %{
      id: partnership.id,
      status: partnership.status,
      nickname: partnership.nickname,
      partnership_level: partnership.partnership_level,
      last_interaction_date: partnership.last_interaction_date,
      partner: %{
        id: partnership.partner.id,
        username: partnership.partner.username,
        display_name: partnership.partner.profile.display_name
      }
    }
  end
end
