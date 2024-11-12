# lib/lovebomb/accounts.ex
defmodule Lovebomb.Accounts do
  @moduledoc """
  The Accounts context handles all user and partnership-related functionality.
  This includes partnership management, interactions, achievements, and statistics.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias Lovebomb.Repo
  alias Lovebomb.Accounts.{User, Partnership, PartnershipInteraction}
  alias Lovebomb.Questions.Answer
  alias Lovebomb.PubSub

  require Logger

  # Partnership Management

  @doc """
  Creates a new partnership between two users.
  Automatically creates the reverse partnership and initializes default settings.

  ## Parameters
    - attrs: Map containing:
      - user_id: ID of the requesting user
      - partner_id: ID of the partner
      - status: Partnership status (default: pending)
      - custom_settings: Optional custom settings

  ## Returns
    - {:ok, partnership} on success
    - {:error, changeset} on validation failure
    - {:error, :user_not_found} if either user doesn't exist
    - {:error, :partnership_exists} if partnership already exists
  """
  def create_partnership(attrs) do
    Multi.new()
    |> Multi.run(:check_users, fn repo, _ ->
      with %User{} = user <- repo.get(User, attrs.user_id),
           %User{} = partner <- repo.get(User, attrs.partner_id) do
        {:ok, {user, partner}}
      else
        nil -> {:error, :user_not_found}
      end
    end)
    |> Multi.run(:check_existing, fn repo, _ ->
      case repo.get_by(Partnership, user_id: attrs.user_id, partner_id: attrs.partner_id) do
        nil -> {:ok, nil}
        _partnership -> {:error, :partnership_exists}
      end
    end)
    |> Multi.insert(:partnership, fn _ ->
      Partnership.changeset(%Partnership{}, attrs)
    end)
    |> Multi.insert(:reverse_partnership, fn %{partnership: p} ->
      Partnership.changeset(%Partnership{}, %{
        user_id: p.partner_id,
        partner_id: p.user_id,
        status: p.status,
        partnership_level: p.partnership_level,
        custom_settings: p.custom_settings
      })
    end)
    |> Multi.run(:notify_partner, fn _repo, %{partnership: partnership} ->
      PubSub.broadcast_partnership_request(partnership)
      {:ok, partnership}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{partnership: partnership}} -> {:ok, partnership}
      {:error, :check_users, :user_not_found, _} -> {:error, :user_not_found}
      {:error, :check_existing, :partnership_exists, _} -> {:error, :partnership_exists}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Gets a partnership between two users with optional preloads.

  ## Parameters
    - user_id: ID of the first user
    - partner_id: ID of the second user
    - preloads: List of associations to preload (default: [:user, :partner])

  ## Returns
    - Partnership struct or nil
  """
  def get_partnership(user_id, partner_id, preloads \\ [:user, :partner]) do
    Partnership
    |> where([p], p.user_id == ^user_id and p.partner_id == ^partner_id)
    |> preload(^preloads)
    |> Repo.one()
  end

  @doc """
  Lists all partnerships for a user with filtering and pagination options.

  ## Parameters
    - user_id: The user's ID
    - opts: Optional parameters
      - status: Filter by status (pending/active/inactive/blocked)
      - preload: List of associations to preload (default: [:partner])
      - limit: Maximum number of records
      - offset: Number of records to skip
      - sort_by: Field to sort by
      - sort_order: :asc or :desc

  ## Returns
    - {partnerships_list, total_count}
  """
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

  @doc """
  Updates partnership status for both the partnership and its reverse.
  Also handles notifications and achievement checks.

  ## Parameters
    - partnership: The partnership to update
    - new_status: The new status to set
    - reason: Optional reason for the status change

  ## Returns
    - {:ok, partnership} on success
    - {:error, changeset} on failure
  """
  def update_partnership_status(partnership, new_status, reason \\ nil) do
    Multi.new()
    |> Multi.update(:partnership, Partnership.status_changeset(partnership, new_status))
    |> Multi.run(:reverse_partnership, fn repo, _ ->
      get_reverse_partnership(repo, partnership)
      |> Partnership.status_changeset(new_status)
      |> repo.update()
    end)
    |> Multi.run(:record_status_change, fn repo, %{partnership: updated_partnership} ->
      record_status_change(repo, updated_partnership, new_status, reason)
    end)
    |> Multi.run(:check_achievements, fn repo, %{partnership: updated_partnership} ->
      check_status_achievements(repo, updated_partnership)
    end)
    |> Multi.run(:notify_users, fn _repo, %{partnership: updated_partnership} ->
      notify_status_change(updated_partnership, new_status, reason)
      {:ok, updated_partnership}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{partnership: partnership}} -> {:ok, partnership}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  def check_status_achievements(rep, updated_partnership) do
    # TODO
  end

  def check_interaction_achievements

  @doc """
  Updates partnership settings with validation and notification.

  ## Parameters
    - partnership: The partnership to update
    - settings: New settings map

  ## Returns
    - {:ok, partnership} on success
    - {:error, changeset} on failure
  """
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

  @doc """
  Records an interaction for a partnership and updates related statistics.

  ## Parameters
    - partnership_id: ID of the partnership
    - attrs: Interaction attributes
      - interaction_type: Type of interaction
      - content: Interaction content
      - metadata: Optional metadata

  ## Returns
    - {:ok, interaction} on success
    - {:error, changeset} on failure
  """
  def record_interaction(partnership_id, attrs) do
    Multi.new()
    |> Multi.run(:partnership, fn repo, _ ->
      {:ok, repo.get!(Partnership, partnership_id)}
    end)
    |> Multi.insert(:interaction, fn %{partnership: partnership} ->
      %PartnershipInteraction{}
      |> PartnershipInteraction.changeset(Map.put(attrs, :partnership_id, partnership.id))
    end)
    |> Multi.update(:update_partnership, fn %{partnership: partnership} ->
      Partnership.interaction_changeset(partnership, attrs)
    end)
    |> Multi.run(:update_stats, fn repo, %{partnership: partnership, interaction: interaction} ->
      update_partnership_stats(repo, partnership, interaction)
    end)
    |> Multi.run(:check_achievements, fn repo, %{partnership: partnership} ->
      check_and_award_achievements(repo, partnership)
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

  @doc """
  Gets comprehensive partnership statistics.

  ## Parameters
    - partnership_id: ID of the partnership

  ## Returns
    - Map of statistics
  """
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

  defp update_partnership_stats(repo, partnership, interaction) do
    stats = compute_updated_stats(partnership, interaction)

    partnership
    |> Partnership.changeset(%{stats: stats})
    |> repo.update()
  end

  defp compute_updated_stats(partnership, interaction) do
    Map.update(partnership.stats, "monthly_activity", %{}, fn monthly ->
      month_key = Calendar.strftime(interaction.inserted_at, "%Y-%m")
      Map.update(monthly, month_key, 1, &(&1 + 1))
    end)
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
    Answer
    |> where([a], a.partnership_id == ^partnership_id)
    |> select([a], %{
      total: count(a.id),
      skipped: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", a.skipped)),
      categories: fragment("json_object_agg(category, count)"),
    })
    |> Repo.one()
  end

  defp check_and_award_achievements(repo, partnership) do
    new_achievements = calculate_new_achievements(partnership)

    if new_achievements != [] do
      partnership
      |> Partnership.changeset(%{
        achievements: partnership.achievements ++ new_achievements
      })
      |> repo.update()
    else
      {:ok, partnership}
    end
  end

  defp calculate_new_achievements(partnership) do
    [
      check_streak_achievements(partnership),
      check_interaction_achievements(partnership),
      check_answer_achievements(partnership)
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 in partnership.achievements))
  end

  def check_interaction_achievements(partnership) do
    # TODO
  end

  def check_streak_achievements(partnership) do
    # Todo
  end

  def check_interaction_achievements do
    # Todo
  end

  def check_answer_achievements(partnership) do
    # TODO
  end

  defp notify_status_change(partnership, new_status, reason) do
    PubSub.broadcast_partnership_status_change(%{
      partnership_id: partnership.id,
      new_status: new_status,
      reason: reason,
      timestamp: DateTime.utc_now()
    })
  end

  defp record_status_change(repo, partnership, new_status, reason) do
    %PartnershipInteraction{}
    |> PartnershipInteraction.changeset(%{
      partnership_id: partnership.id,
      interaction_type: :status_change,
      content: %{
        status: new_status,
        reason: reason
      }
    })
    |> repo.insert()
  end
end
