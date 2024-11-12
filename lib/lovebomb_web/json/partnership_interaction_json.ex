defmodule LovebombWeb.PartnershipInteractionJSON do
  def index(%{interactions: interactions}) do
    %{data: for(interaction <- interactions, do: data(interaction))}
  end

  def show(%{interaction: interaction}) do
    %{data: data(interaction)}
  end

  defp data(interaction) do
    %{
      id: interaction.id,
      type: interaction.interaction_type,
      content: interaction.content,
      metadata: interaction.metadata,
      inserted_at: interaction.inserted_at
    }
  end
end
