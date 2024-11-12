defmodule Lovebomb.Repo.Migrations.AddPointsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users, primary_key: false) do
      add :points, :integer, default: 0, null: false
    end
  end
end
