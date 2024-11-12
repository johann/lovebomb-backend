# priv/repo/migrations/TIMESTAMP_create_user_achievements.exs
defmodule Lovebomb.Repo.Migrations.CreateUserAchievements do
  use Ecto.Migration

  def change do
    create table(:user_achievements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :achievement_type, :string, null: false
      add :granted_at, :utc_datetime, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:user_achievements, [:user_id])
    create unique_index(:user_achievements, [:user_id, :achievement_type])
  end
end
