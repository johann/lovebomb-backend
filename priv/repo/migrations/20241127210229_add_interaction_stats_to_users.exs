defmodule Lovebomb.Repo.Migrations.UpdateUserStatsFields do
  use Ecto.Migration

  def change do
    alter table(:users, primary_key: false) do
      # Add if they don't exist
      add_if_not_exists :interaction_count, :integer, default: 0
      add_if_not_exists :last_interaction_date, :date
      add_if_not_exists :stats, :map, default: %{
        "total_interactions" => 0,
        "interaction_types" => %{},
        "monthly_activity" => %{},
        "achievements" => [],
        "question_categories" => %{},
        "response_times" => %{}
      }
    end

    # Add helpful indexes
    create_if_not_exists index(:users, [:interaction_count])
    create_if_not_exists index(:users, [:last_interaction_date])
  end
end
