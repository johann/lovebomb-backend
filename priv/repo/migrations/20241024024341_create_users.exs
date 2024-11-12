defmodule Lovebomb.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :current_score, :integer, default: 0
      add :highest_level, :integer, default: 1
      add :questions_answered, :integer, default: 0
      add :streak_days, :integer, default: 0
      add :last_answer_date, :date

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
