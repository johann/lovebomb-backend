defmodule Lovebomb.Repo.Migrations.CreatePartnershipInteractions do
  use Ecto.Migration

  def change do
    create table(:partnership_interactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :interaction_type, :string, null: false
      add :content, :map, null: false
      add :metadata, :map, default: %{}
      add :partnership_id, references(:partnerships, type: :binary_id, on_delete: :delete_all)
      add :question_id, references(:questions, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:partnership_interactions, [:partnership_id])
    create index(:partnership_interactions, [:interaction_type])
  end
end
