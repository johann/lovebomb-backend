defmodule Lovebomb.Repo.Migrations.AddActiveAndLevelToUsers do
  use Ecto.Migration

  def change do
    alter table(:users, primary_key: false) do
      add :active, :boolean, default: true
      add :level, :integer, default: 1
    end
  end
end
