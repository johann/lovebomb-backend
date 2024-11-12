defmodule Lovebomb.Repo.Migrations.CreatePartnerships do
  use Ecto.Migration

  def change do
    create table(:partnerships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false
      add :nickname, :string
      add :partnership_level, :integer, default: 1
      add :last_interaction_date, :date
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :partner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:partnerships, [:user_id, :partner_id])
    create index(:partnerships, [:status])
  end
end
