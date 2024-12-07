defmodule Lovebomb.Achievements do
  @moduledoc """
  The Achievements context handles achievement tracking, granting, and related statistics.
  """

  import Ecto.Query
  alias Lovebomb.Repo
  alias Lovebomb.Accounts.{Partnership, User, PartnershipInteraction}
  alias Lovebomb.Questions.Answer
  alias Lovebomb.Achievements.{Achievement, UserAchievement}
  alias Lovebomb.PubSub
  alias Ecto.Multi

  @achievement_types %{
    interaction: %{
      first_interaction: %{
        title: "First Connection",
        description: "Made your first interaction",
        points: 10
      },
      daily_streak_3: %{
        title: "Three Day Streak",
        description: "Interacted for 3 days in a row",
        points: 25
      },
      daily_streak_7: %{
        title: "Week Long Connection",
        description: "Interacted for 7 days in a row",
        points: 50
      },
      daily_streak_30: %{
        title: "Monthly Devotion",
        description: "Interacted for 30 days in a row",
        points: 200
      },
      hundred_interactions: %{
        title: "Century of Connection",
        description: "Reached 100 interactions",
        points: 100
      }
    },
    answers: %{
      first_answer: %{
        title: "First Response",
        description: "Answered your first question",
        points: 10
      },
      ten_answers: %{
        title: "Getting Started",
        description: "Answered 10 questions",
        points: 25
      },
      hundred_answers: %{
        title: "Question Master",
        description: "Answered 100 questions",
        points: 100
      },
      no_skips_10: %{
        title: "Dedicated Responder",
        description: "Answered 10 questions in a row without skipping",
        points: 50
      }
    },
    partnership: %{
      partnership_created: %{
        title: "New Beginning",
        description: "Started a new partnership",
        points: 15
      },
      partnership_level_5: %{
        title: "Growing Together",
        description: "Reached partnership level 5",
        points: 50
      },
      partnership_level_10: %{
        title: "Strong Bond",
        description: "Reached partnership level 10",
        points: 100
      }
    }
  }

  def check_interaction_achievements(partnership) do
    with {:ok, achievements} <- check_interaction_count(partnership),
         {:ok, streak_achievements} <- check_streak_achievements(partnership) do
      all_achievements = achievements ++ streak_achievements
      grant_achievements(partnership, all_achievements)
    end
  end

  def check_streak_achievements(partnership) do
    streak_days = calculate_current_streak(partnership)

    achievements = []
    |> maybe_add_achievement(streak_days >= 3, :daily_streak_3)
    |> maybe_add_achievement(streak_days >= 7, :daily_streak_7)
    |> maybe_add_achievement(streak_days >= 30, :daily_streak_30)

    {:ok, achievements}
  end

  def check_answer_achievements(partnership) do
    answers_query = from a in Answer,
      where: a.partnership_id == ^partnership.id,
      select: %{
        total_count: count(a.id),
        no_skip_streak: fragment("MAX(CASE WHEN ? THEN 1 ELSE 0 END)", a.skipped)
      }

    case Repo.one(answers_query) do
      %{total_count: count, no_skip_streak: streak} ->
        achievements = []
        |> maybe_add_achievement(count >= 1, :first_answer)
        |> maybe_add_achievement(count >= 10, :ten_answers)
        |> maybe_add_achievement(count >= 100, :hundred_answers)
        |> maybe_add_achievement(streak >= 10, :no_skips_10)

        grant_achievements(partnership, achievements)

      nil ->
        {:ok, []}
    end
  end

  def check_status_achievements(repo, updated_partnership) do
    achievements = []
    |> maybe_add_achievement(true, :partnership_created)
    |> maybe_add_achievement(updated_partnership.level >= 5, :partnership_level_5)
    |> maybe_add_achievement(updated_partnership.level >= 10, :partnership_level_10)

    Enum.each(achievements, fn achievement_type ->
      grant_achievement(repo, updated_partnership, achievement_type)
    end)

    {:ok, achievements}
  end

  # Private Functions

  defp check_interaction_count(partnership) do
    interaction_count = Repo.one(from i in PartnershipInteraction,
      where: i.partnership_id == ^partnership.id,
      select: count(i.id))

    achievements = []
    |> maybe_add_achievement(interaction_count >= 1, :first_interaction)
    |> maybe_add_achievement(interaction_count >= 100, :hundred_interactions)

    {:ok, achievements}
  end

  defp calculate_current_streak(partnership) do
    today = Date.utc_today()

    # Get all interaction dates ordered by date
    dates = Repo.all(from i in PartnershipInteraction,
      where: i.partnership_id == ^partnership.id,
      select: fragment("date(inserted_at)"),
      order_by: [desc: fragment("date(inserted_at)")])
      # |> Enum.map(&Date.from_iso8601!/1)

    calculate_streak(dates, today, 0)
  end

  defp calculate_streak([], _, streak), do: streak
  defp calculate_streak([date | rest], expected_date, streak) do
    case Date.compare(date, expected_date) do
      :eq -> calculate_streak(rest, Date.add(expected_date, -1), streak + 1)
      _ -> streak
    end
  end

  defp maybe_add_achievement(achievements, true, achievement_type) do
    [achievement_type | achievements]
  end
  defp maybe_add_achievement(achievements, false, _), do: achievements

  defp grant_achievements(partnership, achievement_types) do
    Enum.each(achievement_types, fn type ->
      grant_achievement(Repo, partnership, type)
    end)

    {:ok, achievement_types}
  end

  defp grant_achievement(repo, partnership, achievement_type) do
    # Check if achievement already granted
    already_granted = repo.exists?(from ua in UserAchievement,
      where: ua.user_id == ^partnership.user_id and
             ua.achievement_type == ^to_string(achievement_type))

    unless already_granted do
      achievement_data = get_achievement_data(achievement_type)

      Multi.new()
      |> Multi.insert(:user_achievement, %UserAchievement{
        user_id: partnership.user_id,
        achievement_type: to_string(achievement_type),
        granted_at: DateTime.utc_now()
      })
      |> Multi.update(:user_points, fn %{user_achievement: _} ->
        from(u in User,
          where: u.id == ^partnership.user_id)
        |> repo.one()
        |> User.points_changeset(%{
          points: achievement_data.points
        })
      end)
      |> repo.transaction()
      |> case do
        {:ok, %{user_achievement: achievement}} ->
          PubSub.broadcast_achievement(
            partnership.user_id,
            achievement_type,
            achievement_data
          )
        {:error, _, changeset, _} ->
          {:error, changeset}
      end
    end
  end

  defp update_achievement_stats(repo, user_id, achievement) do
    user = repo.get!(User, user_id)

    # Get current stats or initialize if empty
    current_stats = user.stats || %{}

    # Get current achievements list or initialize
    current_achievements = current_stats["achievements"] || []

    # Add new achievement to list
    updated_stats = Map.put(current_stats, "achievements", [
      achievement.achievement_type | current_achievements
    ])

    # Update the user with new stats
    user
    |> User.stats_changeset(%{stats: updated_stats})
    |> repo.update()
  end


  defp get_achievement_data(achievement_type) do
    @achievement_types
    |> Enum.find_value(fn {_category, achievements} ->
      Map.get(achievements, achievement_type)
    end)
  end
end
