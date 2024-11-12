# lib/lovebomb/achievements/user_achievement.ex
defmodule Lovebomb.Achievements.UserAchievement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_achievements" do
    field :achievement_type, :string
    field :granted_at, :utc_datetime

    belongs_to :user, Lovebomb.Accounts.User

    timestamps()
  end

  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [:achievement_type, :granted_at, :user_id])
    |> validate_required([:achievement_type, :granted_at, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
