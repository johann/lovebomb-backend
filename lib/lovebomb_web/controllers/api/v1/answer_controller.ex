defmodule LovebombWeb.Api.V1.AnswerController do
  use LovebombWeb, :controller

  alias Lovebomb.Questions
  alias Lovebomb.Accounts

  action_fallback LovebombWeb.FallbackController

  @doc """
  Submit an answer to a question.
  POST /api/v1/answers
  """
  def create(conn, %{"answer" => answer_params}) do
    user = conn.assigns.current_user

    with {:ok, answer} <- Questions.submit_answer(user.id, answer_params),
         :ok <- notify_partners(answer) do

      conn
      |> put_status(:created)
      |> render(:show, answer: answer)
    end
  end

  @doc """
  Get user's answer history.
  GET /api/v1/answers
  Query params:
    - question_id: Filter by question
    - partnership_id: Filter by partnership
    - from: date string, start date
    - to: date string, end date
    - page: integer
    - per_page: integer
  """
  def index(conn, params) do
    user = conn.assigns.current_user

    with {:ok, filters} <- validate_filters(params),
         {:ok, {answers, pagination}} <- Questions.list_user_answers(user.id, filters) do

      conn
      |> put_status(:ok)
      |> render(:index, answers: answers, pagination: pagination)
    end
  end

  @doc """
  Get a specific answer's details.
  GET /api/v1/answers/:id
  """
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, answer} <- Questions.get_answer(id),
         :ok <- authorize_answer_access(user, answer),
         answer_details <- Questions.get_answer_details(answer.id) do

      conn
      |> put_status(:ok)
      |> render(:show, answer: answer, details: answer_details)
    end
  end

  @doc """
  React to an answer (emoji reaction).
  POST /api/v1/answers/:id/react
  """
  def react(conn, %{"id" => id, "reaction" => reaction}) do
    user = conn.assigns.current_user

    with {:ok, answer} <- Questions.get_answer(id),
         :ok <- authorize_answer_access(user, answer),
         {:ok, updated_answer} <- Questions.add_reaction(answer.id, user.id, reaction) do

      conn
      |> put_status(:ok)
      |> render(:show, answer: updated_answer)
    end
  end

  # Private functions

  defp validate_filters(params) do
    try do
      filters = %{
        question_id: params["question_id"],
        partnership_id: params["partnership_id"],
        from_date: parse_date(params["from"]),
        to_date: parse_date(params["to"]),
        page: parse_int(params["page"], 1),
        per_page: parse_int(params["per_page"], 20)
      }

      {:ok, filters}
    rescue
      e in _ ->
        {:error, %{message: "Invalid filter parameters: #{Exception.message(e)}"}}
    end
  end

  # Parameter parsing helpers
  defp parse_int(nil, default), do: default
  defp parse_int(value, default) when is_integer(value), do: value
  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {number, _} -> number
      :error -> default
    end
  end
  defp parse_int(_, default), do: default

  defp parse_date(nil), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date(_), do: nil

  defp authorize_answer_access(user, answer) do
    cond do
      answer.user_id == user.id -> :ok
      Questions.answer_visible_to_user?(answer.id, user.id) -> :ok
      true -> {:error, :unauthorized}
    end
  end

  defp notify_partners(answer) do
    with {:ok, partnerships} <- Accounts.get_active_partnerships(answer.user_id) do
      Enum.each(partnerships, fn partnership ->
        Questions.notify_partner_of_answer(partnership.partner_id, answer)
      end)

      {:ok, answer}
    end
  end
end

# lib/lovebomb_web/controllers/api/v1/question_json.ex
defmodule LovebombWeb.Api.V1.QuestionJSON do
  @doc """
  Renders daily question with user stats.
  """
  def daily(%{question: question, stats: stats}) do
    %{
      data: %{
        question: %{
          id: question.id,
          text: question.text,
          category: question.category,
          difficulty_level: question.difficulty_level,
          score_value: question.score_value,
          metadata: question.metadata
        },
        stats: %{
          questions_answered: stats.questions_answered,
          current_streak: stats.current_streak,
          longest_streak: stats.longest_streak,
          category_progress: stats.category_progress
        }
      }
    }
  end

  @doc """
  Renders list of questions with pagination.
  """
  def index(%{questions: questions, pagination: pagination}) do
    %{
      data: Enum.map(questions, &question_data/1),
      pagination: %{
        page: pagination.page,
        per_page: pagination.per_page,
        total_pages: pagination.total_pages,
        total_entries: pagination.total_entries
      }
    }
  end

  @doc """
  Renders single question with details.
  """
  def show(%{question: question, details: details}) do
    %{
      data: Map.merge(question_data(question), %{
        average_response_time: details.average_response_time,
        completion_rate: details.completion_rate,
        total_answers: details.total_answers,
        category_stats: details.category_stats
      })
    }
  end

  defp question_data(question) do
    %{
      id: question.id,
      text: question.text,
      category: question.category,
      difficulty_level: question.difficulty_level,
      score_value: question.score_value,
      tags: question.tags,
      metadata: question.metadata
    }
  end
end
