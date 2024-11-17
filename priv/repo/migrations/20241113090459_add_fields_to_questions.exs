defmodule Lovebomb.Repo.Migrations.AddFieldsToQuestions do
  use Ecto.Migration

  def change do
    alter table(:questions, primary_key: false) do
      # Add missing fields
      add_if_not_exists :metadata, :map, default: %{}
      add_if_not_exists :stats, :map, default: %{}
      add_if_not_exists :score_value, :integer, default: 10
      add_if_not_exists :language, :string, default: "en"
      add_if_not_exists :author_type, :string, default: "system"
      add_if_not_exists :tags, {:array, :string}, default: []

      # Modify existing fields to ensure they match schema
      modify :content, :text, null: false
      modify :category, :string, null: false
      modify :difficulty_level, :integer, null: false
    end

    # Add helpful indexes if they don't exist
    create_if_not_exists index(:questions, [:category])
    create_if_not_exists index(:questions, [:difficulty_level])
    create_if_not_exists index(:questions, [:active])
  end
end
