defmodule Lovebomb.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :active, :boolean, default: true
    field :level, :integer, default: 1
    field :current_score, :integer, default: 0
    field :points, :integer, default: 0       # Added this field
    field :highest_level, :integer, default: 1
    field :questions_answered, :integer, default: 0
    field :streak_days, :integer, default: 0
    field :last_answer_date, :date

    has_one :profile, Lovebomb.Accounts.Profile
    has_many :partnerships, Lovebomb.Accounts.Partnership
    has_many :partners, through: [:partnerships, :partner]
    has_many :answers, Lovebomb.Questions.Answer
    has_many :achievements, Lovebomb.Achievements.UserAchievement  # Add this association

    field :interaction_count, :integer, default: 0
    field :last_interaction_date, :date
    field :stats, :map, default: %{}

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :email,
      :password,
      :active,
      :level,
      :points,
      :current_score,
      :highest_level,
      :questions_answered,
      :streak_days,
      :last_answer_date
    ])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_number(:level, greater_than_or_equal_to: 1)
    |> validate_number(:points, greater_than_or_equal_to: 0)
    |> validate_number(:current_score, greater_than_or_equal_to: 0)
    |> validate_number(:highest_level, greater_than_or_equal_to: 1)
    |> validate_number(:questions_answered, greater_than_or_equal_to: 0)
    |> validate_number(:streak_days, greater_than_or_equal_to: 0)
    |> validate_number(:interaction_count, greater_than_or_equal_to: 0)
    |> validate_number(:streak_days, greater_than_or_equal_to: 0)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
  end

  def points_changeset(user, attrs) do
    user
    |> cast(attrs, [:points])
    |> validate_required([:points])
    |> validate_number(:points, greater_than_or_equal_to: 0)
  end

  @doc """
  Changeset for updating user statistics, including both
  interaction stats and achievement-related stats.
  """
  def stats_changeset(user, attrs) do
    user
    |> cast(attrs, [
      # Answer/Question related
      :questions_answered,
      :streak_days,
      :last_answer_date,
      :level,
      :highest_level,
      :current_score,
      # Interaction related
      :interaction_count,
      :last_interaction_date,
      :stats,
      # Achievement related
      :points
    ])
    |> validate_required([
      :questions_answered,
      :streak_days,
      :interaction_count
    ])
    |> validate_numbers()
    |> validate_stats_map()
    |> update_highest_level()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end
  defp put_password_hash(changeset), do: changeset

  defp update_highest_level(changeset) do
    case {get_change(changeset, :level), get_field(changeset, :highest_level)} do
      {nil, _} -> changeset
      {new_level, highest_level} when new_level > highest_level ->
        put_change(changeset, :highest_level, new_level)
      _ -> changeset
    end
  end

  # Add these new private functions
  defp validate_numbers(changeset) do
    changeset
    |> validate_number(:questions_answered, greater_than_or_equal_to: 0)
    |> validate_number(:streak_days, greater_than_or_equal_to: 0)
    |> validate_number(:level, greater_than_or_equal_to: 1)
    |> validate_number(:highest_level, greater_than_or_equal_to: 1)
    |> validate_number(:current_score, greater_than_or_equal_to: 0)
    |> validate_number(:interaction_count, greater_than_or_equal_to: 0)
    |> validate_number(:points, greater_than_or_equal_to: 0)
  end

  defp validate_stats_map(changeset) do
    case get_change(changeset, :stats) do
      nil -> changeset
      stats when not is_map(stats) ->
        add_error(changeset, :stats, "must be a map")
      stats ->
        if valid_stats_structure?(stats) do
          changeset
        else
          add_error(changeset, :stats, "has invalid structure")
        end
    end
  end

  defp valid_stats_structure?(stats) do
    required_keys = [
      "total_interactions",
      "interaction_types",
      "monthly_activity",
      "achievements",
      "question_categories",
      "response_times"
    ]

    Enum.all?(required_keys, &Map.has_key?(stats, &1)) and
      is_map(stats["interaction_types"]) and
      is_map(stats["monthly_activity"]) and
      is_list(stats["achievements"]) and
      is_map(stats["question_categories"]) and
      is_map(stats["response_times"])
  end
end
