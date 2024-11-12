defmodule LovebombWeb.Api.V1.QuestionController do
  use LovebombWeb, :controller

  alias Lovebomb.Questions
  alias Lovebomb.Accounts

  action_fallback LovebombWeb.FallbackController

  @doc """
  Get today's question for the user.
  GET /api/v1/questions/daily
  """
  def daily(conn, _params) do
    user = conn.assigns.current_user

    with {:ok, question} <- Questions.get_daily_question(user.id),
         stats <- Questions.get_user_question_stats(user.id) do

      conn
      |> put_status(:ok)
      |> render(:daily, question: question, stats: stats)
    end
  end

  @doc """
  Get user's question history with filters.
  GET /api/v1/questions
  Query params:
    - category: Filter by category
    - answered: boolean, filter by answered status
    - from: date string, start date
    - to: date string, end date
    - page: integer
    - per_page: integer
  """
  def index(conn, params) do
    user = conn.assigns.current_user

    with {:ok, filters} <- validate_filters(params),
         {:ok, {questions, pagination}} <- Questions.list_user_questions(user.id, filters) do

      conn
      |> put_status(:ok)
      |> render(:index, questions: questions, pagination: pagination)
    end
  end

  @doc """
  Get a specific question's details.
  GET /api/v1/questions/:id
  """
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, question} <- Questions.get_question(id),
         :ok <- authorize_question_access(user, question),
         question_details <- Questions.get_question_details(question.id, user.id) do

      conn
      |> put_status(:ok)
      |> render(:show, question: question, details: question_details)
    end
  end

  # Private functions

  defp validate_filters(params) do
    filters = %{
      category: params["category"],
      answered: params["answered"] == "true",
      from_date: parse_date(params["from"]),
      to_date: parse_date(params["to"]),
      page: parse_int(params["page"], 1),
      per_page: parse_int(params["per_page"], 20)
    }

    {:ok, filters}
  rescue
    _ -> {:error, :invalid_filters}
  end

  defp parse_date(nil), do: nil
  defp parse_date(date_string) do
    Date.from_iso8601!(date_string)
  end

  defp parse_int(nil, default), do: default
  defp parse_int(string, default) do
    case Integer.parse(string) do
      {number, _} -> number
      :error -> default
    end
  end

  defp authorize_question_access(user, question) do
    cond do
      Questions.question_available_to_user?(question.id, user.id) -> :ok
      true -> {:error, :unauthorized}
    end
  end
end
