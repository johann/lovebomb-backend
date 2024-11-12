# priv/repo/migrations/TIMESTAMP_update_partnerships_table.exs
defmodule Lovebomb.Repo.Migrations.UpdatePartnershipsTable do
  use Ecto.Migration

  def change do
    alter table(:partnerships, primary_key: false) do
      add_if_not_exists :status, :string
      add_if_not_exists :nickname, :string
      add_if_not_exists :partnership_level, :integer, default: 1
      add_if_not_exists :last_interaction_date, :date
      add_if_not_exists :interaction_count, :integer, default: 0
      add_if_not_exists :streak_days, :integer, default: 0
      add_if_not_exists :last_milestone, :integer, default: 0
      add_if_not_exists :achievements, {:array, :string}, default: []
      add_if_not_exists :mutual_answer_count, :integer, default: 0
      add_if_not_exists :longest_streak, :integer, default: 0
      add_if_not_exists :custom_settings, :map, default: %{}
      add_if_not_exists :stats, :map, default: %{}
    end

    # Add helpful indexes
    create_if_not_exists index(:partnerships, [:status])
    create_if_not_exists index(:partnerships, [:partnership_level])
    create_if_not_exists index(:partnerships, [:last_interaction_date])
    create_if_not_exists index(:partnerships, [:user_id, :partner_id], unique: true)
    create_if_not_exists index(:partnerships, [:streak_days])
    create_if_not_exists index(:partnerships, [:interaction_count])
  end
end
