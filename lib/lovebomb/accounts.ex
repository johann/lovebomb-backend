defmodule Lovebomb.Accounts do
  @moduledoc """
  The Accounts context handles all user and partnership-related functionality.
  This includes user management, partnerships, and basic statistics.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias Lovebomb.Repo
  alias Lovebomb.Accounts.{User, Partnership, PartnershipInteraction, Profile}
  alias Lovebomb.Questions.Answer
  alias Lovebomb.PubSub
  alias Lovebomb.Achievements

  # User Management

  def create_user(attrs) do
    Multi.new()
    |> Multi.insert(:user, User.changeset(%User{}, attrs))
    |> Multi.insert(:profile, fn %{user: user} ->
      Profile.changeset(%Profile{}, %{
        user_id: user.id,
        display_name: attrs["username"] || attrs[:username] || "User"
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, :profile, changeset, _} -> {:error, changeset}
    end
  end

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user(id), do: Repo.get(User, id)

  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    with %User{} = user <- get_user_by_email(email),
         true <- Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      nil -> {:error, :invalid_credentials}
      false -> {:error, :invalid_credentials}
    end
  end

  # Profile Management

  def create_initial_profile(user_id) do
    user = get_user(user_id)

    %Profile{}
    |> Profile.changeset(%{
      user_id: user_id,
      display_name: user.username,
      preferences: %{}
    })
    |> Repo.insert()
  end

  def update_profile(user_id, attrs) do
    Repo.get_by!(Profile, user_id: user_id)
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  # Partnership Management

  def create_partnership(attrs) when is_map(attrs) do
    user_id = attrs[:user_id] || attrs["user_id"]
    partner_id = attrs[:partner_id] || attrs["partner_id"]

    cond do
      is_nil(user_id) -> {:error, %Ecto.Changeset{}}
      is_nil(partner_id) -> {:error, %Ecto.Changeset{}}
      true ->
        Multi.new()
        |> Multi.run(:check_existing, fn repo, _ ->
          query = from p in Partnership,
            where: p.user_id == ^user_id and p.partner_id == ^partner_id
          case repo.exists?(query) do
            false -> {:ok, nil}
            true -> {:error, :partnership_exists}
          end
        end)
        |> Multi.insert(:partnership, fn _ ->
          attrs = for {key, val} <- attrs, into: %{} do
            {to_string(key) |> String.to_atom(), val}
          end
          Partnership.changeset(%Partnership{}, attrs)
        end)
        |> Multi.insert(:reverse_partnership, fn %{partnership: p} ->
          Partnership.changeset(%Partnership{}, %{
            user_id: p.partner_id,
            partner_id: p.user_id,
            status: p.status || :pending,
            partnership_level: p.partnership_level || 1
          })
        end)
        |> Multi.run(:notify_partner, fn _repo, %{partnership: partnership} ->
          try do
            PubSub.broadcast_partnership_request(partnership)
          rescue
            _ -> :ok
          end
          {:ok, partnership}
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{partnership: partnership}} -> {:ok, partnership}
          {:error, :check_existing, :partnership_exists, _} -> {:error, :partnership_exists}
          {:error, :partnership, changeset, _} -> {:error, changeset}
          {:error, _, changeset, _} -> {:error, changeset}
        end
    end
  end

  def get_partnership(user_id, partner_id, preloads \\ [:user, :partner]) do
    Partnership
    |> where([p], p.user_id == ^user_id and p.partner_id == ^partner_id)
    |> preload(^preloads)
    |> Repo.one()
  end

  def list_partnerships(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    preload = Keyword.get(opts, :preload, [:partner])
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    query = from p in Partnership,
      where: p.user_id == ^user_id,
      select: p

    query = if status, do: where(query, [p], p.status == ^status), else: query

    query = from p in query,
      order_by: [{^sort_order, ^sort_by}],
      limit: ^limit,
      offset: ^offset,
      preload: ^preload

    total_query = from p in Partnership,
      where: p.user_id == ^user_id,
      select: count(p.id)

    total_query = if status, do: where(total_query, [p], p.status == ^status), else: total_query

    {Repo.all(query), Repo.one(total_query)}
  end

  # def update_partnership_status(partnership, new_status, reason \\ nil) do
  #   Multi.new()
  #   |> Multi.update(:partnership, Partnership.status_changeset(partnership, new_status))
  #   |> Multi.run(:reverse_partnership, fn repo, _ ->
  #     get_reverse_partnership(repo, partnership)
  #     |> Partnership.status_changeset(new_status)
  #     |> repo.update()
  #   end)
  #   |> Multi.insert(:status_change, fn %{partnership: updated_partnership} ->
  #     PartnershipInteraction.changeset(%PartnershipInteraction{}, %{
  #       partnership_id: updated_partnership.id,
  #       interaction_type: :status_change,
  #       content: %{
  #         status: new_status,
  #         reason: reason
  #       }
  #     })
  #   end)
  #   |> Multi.run(:notify_users, fn _repo, %{partnership: updated_partnership} ->
  #     try do
  #       notify_status_change(updated_partnership, new_status, reason)
  #     rescue
  #       _ -> :ok
  #     end
  #     {:ok, updated_partnership}
  #   end)
  #   |> Multi.run(:check_achievements, fn repo, %{partnership: updated_partnership} ->
  #     Achievements.check_status_achievements(repo, updated_partnership)
  #   end)
  #   |> Repo.transaction()
  #   |> case do
  #     {:ok, %{partnership: partnership}} -> {:ok, partnership}
  #     {:error, :partnership, changeset, _} -> {:error, changeset}
  #     {:error, _, changeset, _} -> {:error, changeset}
  #   end
  # end

  def update_partnership_status(partnership, new_status, reason \\ nil) do
    Multi.new()
    |> Multi.update(:partnership, Partnership.status_changeset(partnership, new_status))
    |> Multi.run(:reverse_partnership, fn repo, _ ->
      case repo.get_by(Partnership,
        user_id: partnership.partner_id,
        partner_id: partnership.user_id
      ) do
        nil -> {:error, :reverse_partnership_not_found}
        reverse ->
          Partnership.status_changeset(reverse, new_status)
          |> repo.update()
      end
    end)
    |> Multi.insert(:status_change, fn %{partnership: updated_partnership} ->
      PartnershipInteraction.changeset(%PartnershipInteraction{}, %{
        partnership_id: updated_partnership.id,
        interaction_type: :status_change,
        content: %{
          status: new_status,
          reason: reason
        }
      })
    end)
    |> Multi.run(:notify_users, fn _repo, %{partnership: updated_partnership} ->
      notify_status_change(updated_partnership, new_status, reason)
      {:ok, updated_partnership}
    end)
    |> Multi.run(:check_achievements, fn repo, %{partnership: updated_partnership} ->
      Achievements.check_status_achievements(repo, updated_partnership)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{partnership: partnership}} -> {:ok, partnership}
      {:error, :reverse_partnership_not_found, _, _} -> {:error, :reverse_partnership_not_found}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def update_partnership_settings(partnership, settings) do
    Multi.new()
    |> Multi.update(:partnership, Partnership.settings_changeset(partnership, settings))
    |> Multi.run(:reverse_partnership, fn repo, _ ->
      get_reverse_partnership(repo, partnership)
      |> Partnership.settings_changeset(settings)
      |> repo.update()
    end)
    |> Multi.run(:notify_settings_change, fn _repo, %{partnership: updated_partnership} ->
      PubSub.broadcast_partnership_settings_update(updated_partnership)
      {:ok, updated_partnership}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{partnership: partnership}} -> {:ok, partnership}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  # def record_interaction(partnership_id, attrs) do
  #   Multi.new()
  #   |> Multi.run(:partnership, fn repo, _ ->
  #     {:ok, repo.get!(Partnership, partnership_id) |> repo.preload([:user, :partner])}
  #   end)
  #   |> Multi.insert(:interaction, fn %{partnership: partnership} ->
  #     %PartnershipInteraction{}
  #     |> PartnershipInteraction.changeset(Map.put(attrs, :partnership_id, partnership.id))
  #   end)
  #   |> Multi.update(:update_partnership, fn %{partnership: partnership} ->
  #     Partnership.interaction_changeset(partnership, attrs)
  #   end)
  #   |> Multi.update(:update_user_stats, fn %{partnership: partnership, interaction: interaction} ->
  #     update_user_interaction_stats(partnership.user, interaction)
  #   end)
  #   |> Multi.update(:update_partner_stats, fn %{partnership: partnership, interaction: interaction} ->
  #     update_user_interaction_stats(partnership.partner, interaction)
  #   end)
  #   |> Multi.run(:check_achievements, fn _repo, %{partnership: partnership} ->
  #     Achievements.check_interaction_achievements(partnership)
  #   end)
  #   |> Multi.run(:notify_interaction, fn _repo, %{interaction: interaction} ->
  #     PubSub.broadcast_partnership_interaction(interaction)
  #     {:ok, interaction}
  #   end)
  #   |> Repo.transaction()
  #   |> case do
  #     {:ok, %{interaction: interaction}} -> {:ok, interaction}
  #     {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
  #   end
  # end

  def record_interaction(partnership_id, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Multi.new()
    |> Multi.run(:partnership, fn repo, _ ->
      {:ok, repo.get!(Partnership, partnership_id) |> repo.preload([:user, :partner])}
    end)
    |> Multi.insert(:interaction, fn %{partnership: partnership} ->
      attrs = Map.put(attrs, :inserted_at, now)
      %PartnershipInteraction{}
      |> PartnershipInteraction.changeset(Map.put(attrs, :partnership_id, partnership.id))
    end)
    |> Multi.update(:update_partnership, fn %{partnership: partnership} ->
      Partnership.interaction_changeset(partnership, attrs)
    end)
    |> Multi.update(:update_user_stats, fn %{partnership: partnership, interaction: interaction} ->
      update_user_interaction_stats(partnership.user, interaction)
    end)
    |> Multi.update(:update_partner_stats, fn %{partnership: partnership, interaction: interaction} ->
      update_user_interaction_stats(partnership.partner, interaction)
    end)
    |> Multi.run(:check_achievements, fn _repo, %{partnership: partnership} ->
      Achievements.check_interaction_achievements(partnership)
    end)
    |> Multi.run(:notify_interaction, fn _repo, %{interaction: interaction} ->
      PubSub.broadcast_partnership_interaction(interaction)
      {:ok, interaction}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{interaction: interaction}} -> {:ok, interaction}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  # Partnership Statistics

  def get_partnership_stats(partnership_id) do
    partnership = Repo.get!(Partnership, partnership_id)

    base_stats = %{
      partnership_level: partnership.partnership_level,
      streak_days: partnership.streak_days,
      longest_streak: partnership.longest_streak,
      total_interactions: partnership.interaction_count,
      days_connected: Timex.diff(Date.utc_today(), partnership.inserted_at, :days),
      achievements: partnership.achievements,
      last_interaction: partnership.last_interaction_date
    }

    interaction_stats = compute_interaction_stats(partnership_id)
    answer_stats = compute_answer_stats(partnership_id)

    Map.merge(base_stats, %{
      interactions: interaction_stats,
      answers: answer_stats
    })
  end

  # Private Functions

  defp get_reverse_partnership(repo, partnership) do
    repo.get_by!(Partnership,
      user_id: partnership.partner_id,
      partner_id: partnership.user_id
    )
  end

  defp update_user_interaction_stats(user, interaction) do
    today = Date.utc_today()

    user
    |> User.stats_changeset(%{
      interaction_count: (user.interaction_count || 0) + 1,
      last_interaction_date: today,
      stats: update_user_stats_map(user.stats || %{}, interaction)
    })
  end

  defp update_user_stats_map(current_stats, interaction) do
    current_datetime = case interaction.inserted_at do
      %DateTime{} = dt -> dt
      %NaiveDateTime{} = ndt ->
        DateTime.from_naive!(ndt, "Etc/UTC")
      _ -> DateTime.utc_now()
    end

    Map.merge(current_stats, %{
      "total_interactions" => (current_stats["total_interactions"] || 0) + 1,
      "interaction_types" => update_interaction_types(
        current_stats["interaction_types"] || %{},
        interaction.interaction_type
      ),
      "monthly_activity" => update_monthly_activity(
        current_stats["monthly_activity"] || %{},
        current_datetime
      ),
      "last_interaction_type" => interaction.interaction_type,
      "last_interaction_time" => DateTime.to_iso8601(current_datetime)
    })
  end

  defp update_interaction_types(types, new_type) do
    Map.update(types, to_string(new_type), 1, &(&1 + 1))
  end

  defp update_monthly_activity(activity, date) do
    month_key = Calendar.strftime(date, "%Y-%m")
    Map.update(activity, month_key, 1, &(&1 + 1))
  end

  defp compute_interaction_stats(partnership_id) do
    PartnershipInteraction
    |> where([i], i.partnership_id == ^partnership_id)
    |> group_by([i], i.interaction_type)
    |> select([i], {i.interaction_type, count(i.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp compute_answer_stats(partnership_id) do
    base_query = from a in Answer,
      where: a.partnership_id == ^partnership_id,
      select: %{
        total: count(a.id),
        skipped: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", a.skipped))
      }

    case Repo.one(base_query) do
      nil -> %{total: 0, skipped: 0, categories: %{}}
      stats -> Map.put(stats, :categories, %{})  # Add empty categories for now
    end
  end

  defp notify_status_change(partnership, new_status, reason) do
    PubSub.broadcast_partnership_status_change(%{
      partnership_id: partnership.id,
      new_status: new_status,
      reason: reason,
      timestamp: DateTime.utc_now()
    })
  end
end
