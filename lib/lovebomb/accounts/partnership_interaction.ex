defmodule Lovebomb.Accounts.PartnershipInteraction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "partnership_interactions" do
    field :interaction_type, Ecto.Enum,
      values: [:answer_shared, :reaction, :message, :achievement, :status_change]
    field :content, :map
    field :metadata, :map, default: %{}

    belongs_to :partnership, Lovebomb.Accounts.Partnership
    belongs_to :question, Lovebomb.Questions.Question

    timestamps()
  end

  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:interaction_type, :content, :metadata, :partnership_id, :question_id])
    |> validate_required([:interaction_type, :content, :partnership_id])
  end
end
