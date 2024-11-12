defmodule Lovebomb.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :display_name, :string, null: false
      add :bio, :text
      add :avatar_url, :string
      add :preferences, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:profiles, [:user_id])
  end
end
