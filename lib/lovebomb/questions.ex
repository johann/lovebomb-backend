defmodule Lovebomb.Questions do
  @moduledoc """
  The Questions context manages all question and answer related functionality.
  Including daily questions, answers, statistics, and partnership interactions.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias Lovebomb.Repo
  alias Lovebomb.Questions.{Question, Answer}
  alias Lovebomb.Accounts.{User, Partnership}
  alias Lovebomb.PubSub
  alias Lovebomb.Questions.Stats

  @type validation_error ::
    :inactive_user
    | :user_not_found
    | :inactive_question
    | :question_not_found
    | :already_answered_today
    | :level_mismatch
    | :already_answered
    | :too_soon_to_repeat
    | :no_questions_available

  # Question Management

  @doc """
  Gets the daily question for a user based on their level and history.
  Ensures questions aren't repeated and match the user's current level.

  Returns `{:ok, question}` or `{:error, reason}`.
  """
  @spec get_daily_question(integer()) :: {:ok, Question.t()} | {:error, validation_error()}
  def get_daily_question(user_id) do
    user = Repo.get!(User, user_id)
    today = Date.utc_today()

    with nil <- get_cached_daily_question(user_id, today),
         {:ok, question} <- select_appropriate_question(user) do
      cache_daily_question(user_id, today, question)
      {:ok, question}
    else
      {:error, reason} -> {:error, reason}
      cached_question -> {:ok, cached_question}
    end
  end

  @doc """
  Records a user's answer to a question.
  Updates user stats and notifies partners.

  ## Parameters
    - user_id: The ID of the user submitting the answer
    - question_id: The ID of the question being answered
    - attrs: Map containing answer attributes:
      - content: The answer text
      - skipped: Boolean indicating if question was skipped
      - skip_reason: Optional reason if skipped
      - difficulty_rating: User's rating of question difficulty (1-5)

  Returns `{:ok, answer}` or `{:error, changeset}`.
  """
  @spec submit_answer(integer(), integer(), map()) ::
    {:ok, Answer.t()} | {:error, Ecto.Changeset.t()}
  def submit_answer(user_id, question_id, attrs) do
    Multi.new()
    |> Multi.run(:check_daily, fn repo, _ ->
      validate_daily_question(repo, user_id, question_id)
    end)
    |> Multi.run(:answer, fn repo, _ ->
      create_answer(repo, user_id, question_id, attrs)
    end)
    |> Multi.run(:update_user_stats, fn repo, %{answer: answer} ->
      update_user_stats(repo, user_id, answer)
    end)
    |> Multi.run(:update_question_stats, fn repo, %{answer: answer} ->
      update_question_stats(repo, question_id, answer)
    end)
    |> Multi.run(:notify_partners, fn _repo, %{answer: answer} ->
      notify_partners_of_answer(answer)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{answer: answer}} -> {:ok, answer}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Lists answers for a partnership with filtering and pagination.

  ## Options
    - limit: Number of answers per page (default: 20)
    - offset: Number of answers to skip (default: 0)
    - category: Optional category filter

  Returns `{results, metadata}` where metadata contains pagination info.
  """
  @spec list_partnership_answers(integer(), keyword()) ::
    {[Answer.t()], map()}
  def list_partnership_answers(partnership_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    category = Keyword.get(opts, :category)

    base_query = Answer
      |> where([a], a.partnership_id == ^partnership_id)
      |> order_by([a], [desc: a.inserted_at])
      |> preload([:question, :user])

    query = if category do
      base_query
      |> join(:inner, [a], q in assoc(a, :question))
      |> where([a, q], q.category == ^category)
    else
      base_query
    end

    total_count = query
      |> exclude(:order_by)
      |> exclude(:preload)
      |> select(count("*"))
      |> Repo.one()

    results = query
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    {results,
     %{
       total_entries: total_count,
       page_size: limit,
       page_number: div(offset, limit) + 1,
       total_pages: ceil(total_count / limit)
     }}
  end

  @doc """
  Validates if a question can be answered by a user today.
  """
  @spec validate_daily_question(Repo.t(), integer(), integer()) ::
    {:ok, Question.t()} | {:error, validation_error()}
  def validate_daily_question(repo, user_id, question_id) do
    with {:ok, user} <- get_active_user(repo, user_id),
         {:ok, question} <- get_active_question(repo, question_id),
         :ok <- validate_not_answered_today(repo, user_id, question_id),
         :ok <- validate_level_appropriate(question, user),
         :ok <- validate_repeat_period(repo, user_id, question) do
      {:ok, question}
    end
  end

  # Private Functions

  @spec get_active_user(Repo.t(), integer()) ::
    {:ok, User.t()} | {:error, :inactive_user | :user_not_found}
  defp get_active_user(repo, user_id) do
    case repo.get(User, user_id) do
      # %User{active: true} = user -> {:ok, user}
      # %User{active: false} -> {:error, :inactive_user}
      nil -> {:error, :user_not_found}
    end
  end

  @spec get_active_question(Repo.t(), integer()) ::
    {:ok, Question.t()} | {:error, :inactive_question | :question_not_found}
  defp get_active_question(repo, question_id) do
    case repo.get(Question, question_id) do
      %Question{active: true} = question -> {:ok, question}
      %Question{active: false} -> {:error, :inactive_question}
      nil -> {:error, :question_not_found}
    end
  end

  @spec validate_not_answered_today(Repo.t(), integer(), integer()) ::
    :ok | {:error, :already_answered_today}
  defp validate_not_answered_today(repo, user_id, question_id) do
    today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00.000], "Etc/UTC")

    query = from a in Answer,
      where: a.user_id == ^user_id and
             a.question_id == ^question_id and
             a.inserted_at >= ^today_start

    case repo.exists?(query) do
      true -> {:error, :already_answered_today}
      false -> :ok
    end
  end

  @spec validate_level_appropriate(Question.t(), User.t()) ::
    :ok | {:error, :level_mismatch}
  defp validate_level_appropriate(question, user) do
    min_level = question.min_level || 0
    max_level = question.max_level || 999

    if user.level >= min_level and user.level <= max_level do
      :ok
    else
      {:error, :level_mismatch}
    end
  end

  @spec validate_repeat_period(Repo.t(), integer(), Question.t()) ::
    :ok | {:error, :already_answered | :too_soon_to_repeat}
  defp validate_repeat_period(repo, user_id, question) do
    case question.repeat_after_days do
      nil -> validate_never_answered(repo, user_id, question.id)
      days -> validate_repeat_days(repo, user_id, question.id, days)
    end
  end

  defp validate_never_answered(repo, user_id, question_id) do
    query = from a in Answer,
      where: a.user_id == ^user_id and
             a.question_id == ^question_id

    case repo.exists?(query) do
      true -> {:error, :already_answered}
      false -> :ok
    end
  end

  defp validate_repeat_days(repo, user_id, question_id, repeat_after_days) do
    repeat_threshold =
      DateTime.utc_now()
      |> DateTime.add(-repeat_after_days * 24 * 60 * 60, :second)

    query = from a in Answer,
      where: a.user_id == ^user_id and
             a.question_id == ^question_id and
             a.inserted_at > ^repeat_threshold

    case repo.exists?(query) do
      true -> {:error, :too_soon_to_repeat}
      false -> :ok
    end
  end

  defp select_appropriate_question(user) do
    answered_questions = get_user_answered_questions(user.id)

    Question
    |> where([q], q.active == true)
    |> where([q], q.difficulty_level <= ^user.highest_level)
    |> where([q], q.id not in ^answered_questions)
    |> order_by(fragment("RANDOM()"))
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, :no_questions_available}
      question -> {:ok, question}
    end
  end

  defp get_user_answered_questions(user_id) do
    Answer
    |> where([a], a.user_id == ^user_id)
    |> select([a], a.question_id)
    |> Repo.all()
  end

  defp create_answer(repo, user_id, question_id, attrs) do
    %Answer{}
    |> Answer.changeset(Map.merge(attrs, %{
      user_id: user_id,
      question_id: question_id,
      answered_at: DateTime.utc_now()
    }))
    |> repo.insert()
  end

  defp update_user_stats(repo, user_id, answer) do
    user = repo.get!(User, user_id)
    stats = calculate_updated_user_stats(user, answer)

    user
    |> User.stats_changeset(stats)
    |> repo.update()
  end

  defp calculate_updated_user_stats(user, answer) do
    base_stats = %{
      questions_answered: user.questions_answered + 1,
      last_answer_date: Date.utc_today()
    }

    if answer.skipped do
      Map.put(base_stats, :streak_days, 0)
    else
      Map.put(base_stats, :streak_days, user.streak_days + 1)
    end
  end

  defp update_question_stats(repo, question_id, answer) do
    question = repo.get!(Question, question_id)
    stats = calculate_updated_question_stats(question, answer)

    question
    |> Question.stats_changeset(%{stats: stats})
    |> repo.update()
  end

  defp calculate_updated_question_stats(question, answer) do
    current_stats = question.stats || %{}
    times_asked = (current_stats["times_asked"] || 0) + 1

    %{
      "times_asked" => times_asked,
      "skip_rate" => calculate_skip_rate(current_stats, answer, times_asked),
      "avg_response_length" => calculate_avg_response_length(current_stats, answer, times_asked),
      "avg_difficulty_rating" => calculate_avg_difficulty(current_stats, answer, times_asked)
    }
  end

  defp calculate_skip_rate(stats, answer, times_asked) do
    current_skips = (stats["times_skipped"] || 0) + (if answer.skipped, do: 1, else: 0)
    Float.round(current_skips / times_asked * 100, 1)
  end

  defp calculate_avg_response_length(stats, answer, times_asked) do
    return_zero_if_skipped(answer.skipped) do
      current_total = (stats["total_response_length"] || 0) + String.length(answer.content)
      Float.round(current_total / times_asked, 1)
    end
  end

  defp calculate_avg_difficulty(stats, answer, times_asked) do
    return_zero_if_skipped(answer.skipped) do
      current_total = (stats["total_difficulty_rating"] || 0) + answer.difficulty_rating
      Float.round(current_total / times_asked, 1)
    end
  end

  defp return_zero_if_skipped(skipped, calculation) do
    if skipped, do: 0, else: calculation.()
  end

  defp notify_partners_of_answer(answer) do
    partnerships = Repo.all(from p in Partnership,
      where: p.user_id == ^answer.user_id and p.status == :active)

    Enum.each(partnerships, fn partnership ->
      PubSub.broadcast_new_answer(partnership.partner_id, answer)
    end)

    {:ok, answer}
  end

  # Cache Implementation
  defp get_cached_daily_question(user_id, date) do
    Lovebomb.Cache.QuestionCache.get("daily:#{user_id}:#{Date.to_string(date)}")
  end

  defp cache_daily_question(user_id, date, question) do
    Lovebomb.Cache.QuestionCache.put(
      "daily:#{user_id}:#{Date.to_string(date)}",
      question,
      86400  # Cache for 24 hours
    )
  end

  # Stats Access Functions
  defdelegate get_question_stats(question_id), to: Stats, as: :calculate_question_stats
  defdelegate get_user_question_stats(user_id), to: Stats, as: :calculate_user_stats
  defdelegate get_partnership_answer_stats(partnership_id), to: Stats, as: :calculate_partnership_stats
end
