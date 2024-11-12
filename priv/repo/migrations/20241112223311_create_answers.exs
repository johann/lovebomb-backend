# priv/repo/migrations/TIMESTAMP_create_answers.exs
defmodule Lovebomb.Repo.Migrations.CreateAnswers do
  use Ecto.Migration

  def change do
    create table(:answers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text
      add :skipped, :boolean, default: false
      add :skip_reason, :string
      add :difficulty_rating, :integer
      add :answered_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :question_id, references(:questions, type: :binary_id, on_delete: :delete_all)
      add :partnership_id, references(:partnerships, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:answers, [:user_id])
    create index(:answers, [:question_id])
    create index(:answers, [:partnership_id])
  end
end
