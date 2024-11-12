defmodule Lovebomb.Accounts.Partnership do
  @moduledoc """
  Schema and changeset for partnerships between users.
  Handles bi-directional relationships, progression, and interaction tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Lovebomb.Accounts.{User, PartnershipInteraction}
  alias Lovebomb.Questions.Answer

  @partnership_levels 1..100
  @achievement_types [
    "first_connection",
    "week_streak",
    "month_streak",
    "perfect_week",
    "answer_streak_3",
    "answer_streak_7",
    "answer_streak_30",
    "mutual_answers_10",
    "mutual_answers_50",
    "mutual_answers_100",
    "rapid_responder",
    "deep_connection",
    "consistent_partner"
  ]

  @default_custom_settings %{
    "notification_preferences" => %{
      "answers" => true,
      "daily_reminder" => true,
      "achievements" => true
    },
    "privacy_settings" => %{
      "share_streak" => true,
      "share_achievements" => true
    },
    "display_preferences" => %{
      "show_level" => true,
      "show_streak" => true
    }
  }

  @default_stats %{
    "questions_answered" => 0,
    "questions_skipped" => 0,
    "total_interaction_time" => 0,
    "average_response_time" => 0,
    "category_preferences" => %{},
    "monthly_activity" => %{}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "partnerships" do
    field :status, Ecto.Enum, values: [:pending, :active, :inactive, :blocked]
    field :nickname, :string
    field :partnership_level, :integer, default: 1
    field :last_interaction_date, :date
    field :interaction_count, :integer, default: 0
    field :streak_days, :integer, default: 0
    field :last_milestone, :integer, default: 0
    field :achievements, {:array, :string}, default: []
    field :mutual_answer_count, :integer, default: 0
    field :longest_streak, :integer, default: 0

    # Custom settings for partnership
    field :custom_settings, :map, default: %{
      "notification_preferences" => %{
        "answers" => true,
        "daily_reminder" => true,
        "achievements" => true
      },
      "privacy_settings" => %{
        "share_streak" => true,
        "share_achievements" => true
      },
      "display_preferences" => %{
        "show_level" => true,
        "show_streak" => true
      }
    }

    # Stats tracking
    field :stats, :map, default: %{
      "questions_answered" => 0,
      "questions_skipped" => 0,
      "total_interaction_time" => 0,
      "average_response_time" => 0,
      "category_preferences" => %{},
      "monthly_activity" => %{}
    }

    belongs_to :user, User
    belongs_to :partner, User

    has_many :interactions, PartnershipInteraction
    has_many :shared_answers, Answer, foreign_key: :partnership_id
    has_many :shared_questions, through: [:interactions, :question]

    timestamps()
  end

  @doc """
  Creates a changeset for a new partnership or updates an existing one.

  ## Parameters
    - partnership: The current partnership struct (or %Partnership{} for new ones)
    - attrs: The attributes to set/update

  ## Returns
    - Ecto.Changeset
  """
  def changeset(partnership, attrs) do
    partnership
    |> cast(attrs, [
      :status, :nickname, :partnership_level, :last_interaction_date,
      :user_id, :partner_id, :interaction_count, :streak_days,
      :last_milestone, :achievements, :mutual_answer_count,
      :longest_streak, :custom_settings, :stats
    ])
    |> validate_required([:status, :user_id, :partner_id])
    |> validate_inclusion(:partnership_level, @partnership_levels)
    |> validate_inclusion(:status, [:pending, :active, :inactive, :blocked])
    |> validate_length(:nickname, max: 50)
    |> validate_achievements()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:partner_id)
    |> unique_constraint([:user_id, :partner_id])
    |> check_partner_self()
    |> validate_custom_settings()
    |> validate_stats()
  end

  @doc """
  Creates a changeset specifically for updating partnership status.

  ## Parameters
    - partnership: The current partnership struct
    - status: The new status to set

  ## Returns
    - Ecto.Changeset
  """
  def status_changeset(partnership, status) do
    partnership
    |> cast(%{status: status}, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, [:pending, :active, :inactive, :blocked])
  end

  @doc """
  Creates a changeset for updating partnership settings.

  ## Parameters
    - partnership: The current partnership struct
    - settings: Map of settings to update

  ## Returns
    - Ecto.Changeset
  """
  def settings_changeset(partnership, settings) do
    partnership
    |> cast(%{custom_settings: settings}, [:custom_settings])
    |> validate_custom_settings()
  end

  @doc """
  Creates a changeset for recording an interaction.

  ## Parameters
    - partnership: The current partnership struct
    - attrs: Interaction attributes

  ## Returns
    - Ecto.Changeset
  """
  def interaction_changeset(partnership, _attrs) do
    today = Date.utc_today()

    partnership
    |> change()
    |> put_change(:last_interaction_date, today)
    |> put_change(:interaction_count, (partnership.interaction_count || 0) + 1)
    |> update_streak(today)
  end

  # Private functions

  defp validate_achievements(changeset) do
    case get_change(changeset, :achievements) do
      nil -> changeset
      achievements ->
        if Enum.all?(achievements, &(&1 in @achievement_types)) do
          changeset
        else
          add_error(changeset, :achievements, "contains invalid achievement type")
        end
    end
  end

  defp check_partner_self(changeset) do
    user_id = get_field(changeset, :user_id)
    partner_id = get_field(changeset, :partner_id)

    if user_id == partner_id do
      add_error(changeset, :partner_id, "cannot create partnership with yourself")
    else
      changeset
    end
  end

  defp validate_custom_settings(changeset) do
    case get_change(changeset, :custom_settings) do
      nil -> changeset
      settings ->
        cond do
          !is_map(settings) ->
            add_error(changeset, :custom_settings, "must be a map")
          !valid_settings_structure?(settings) ->
            add_error(changeset, :custom_settings, "has invalid structure")
          true ->
            changeset
        end
    end
  end

  defp valid_settings_structure?(settings) do
    required_keys = ["notification_preferences", "privacy_settings", "display_preferences"]
    Enum.all?(required_keys, &Map.has_key?(settings, &1))
  end

  defp validate_stats(changeset) do
    case get_change(changeset, :stats) do
      nil -> changeset
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
      "questions_answered",
      "questions_skipped",
      "total_interaction_time",
      "average_response_time",
      "category_preferences",
      "monthly_activity"
    ]
    Enum.all?(required_keys, &Map.has_key?(stats, &1))
  end

  defp update_streak(changeset, today) do
    case get_field(changeset, :last_interaction_date) do
      nil ->
        put_change(changeset, :streak_days, 1)
      last_date ->
        days_diff = Date.diff(today, last_date)
        current_streak = get_field(changeset, :streak_days)
        longest_streak = get_field(changeset, :longest_streak)

        {new_streak, new_longest} = calculate_streak(days_diff, current_streak, longest_streak)

        changeset
        |> put_change(:streak_days, new_streak)
        |> put_change(:longest_streak, new_longest)
    end
  end

  defp calculate_streak(days_diff, current_streak, longest_streak) do
    new_streak = case days_diff do
      1 -> current_streak + 1
      0 -> current_streak
      _ -> 1
    end

    new_longest = max(new_streak, longest_streak)
    {new_streak, new_longest}
  end
end
