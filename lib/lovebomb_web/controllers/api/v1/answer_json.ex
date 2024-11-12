# lib/lovebomb_web/controllers/api/v1/answer_json.ex
defmodule LovebombWeb.Api.V1.AnswerJSON do
  @doc """
  Renders a single answer.
  """
  def show(%{answer: answer}) do
    %{
      data: answer_data(answer)
    }
  end

  @doc """
  Renders a list of answers with pagination.
  """
  def index(%{answers: answers, pagination: pagination}) do
    %{
      data: Enum.map(answers, &answer_data/1),
      pagination: %{
        page: pagination.page,
        per_page: pagination.per_page,
        total_pages: pagination.total_pages,
        total_entries: pagination.total_entries
      }
    }
  end

  defp answer_data(answer) do
    %{
      id: answer.id,
      text: answer.text,
      skipped: answer.skipped,
      skip_reason: answer.skip_reason,
      visibility: answer.visibility,
      reactions: answer.reactions,
      difficulty_rating: answer.difficulty_rating,
      metadata: answer.metadata,
      inserted_at: answer.inserted_at,
      question: %{
        id: answer.question.id,
        text: answer.question.text,
        category: answer.question.category
      }
    }
  end
end
