defmodule Lovebomb.Repo.Migrations.CreateQuestions do
  use Ecto.Migration

  def change do
    create table(:questions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :category, :string, null: false
      add :difficulty_level, :integer, null: false
      add :min_level, :integer
      add :max_level, :integer
      add :active, :boolean, default: true
      add :repeat_after_days, :integer
      add :stats, :map, default: %{}

      timestamps()
    end

    create index(:questions, [:category])
    create index(:questions, [:difficulty_level])
  end
end
