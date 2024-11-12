defmodule Lovebomb.Questions.Stats do
  @moduledoc """
  Provides statistical calculations for questions and answers.
  """

  import Ecto.Query
  alias Lovebomb.Repo
  alias Lovebomb.Questions.{Question, Answer}

  @doc """
  Calculate various statistics for a question.
  """
  def calculate_question_stats(question_id) do
    answers = Repo.all(from a in Answer,
      where: a.question_id == ^question_id,
      preload: [:user])

    %{
      times_asked: length(answers),
      skip_rate: calculate_skip_rate(answers),
      avg_response_time: calculate_avg_response_time(answers),
      avg_response_length: calculate_avg_response_length(answers),
      avg_difficulty_rating: calculate_avg_difficulty_rating(answers),
      total_answers: length(answers),
      completion_rate: calculate_completion_rate(answers),
      category_performance: calculate_category_performance(answers)
    }
  end

  @doc """
  Calculate skip rate for answers.
  """
  def calculate_skip_rate(answers) when is_list(answers) do
    total = length(answers)
    case total do
      0 -> 0.0
      _ ->
        skipped = Enum.count(answers, & &1.skipped)
        Float.round(skipped / total * 100, 2)
    end
  end

  @doc """
  Calculate average response length for non-skipped answers.
  """
  def calculate_avg_response_length(answers) when is_list(answers) do
    valid_answers = Enum.reject(answers, & &1.skipped)

    case length(valid_answers) do
      0 -> 0
      total ->
        total_length = Enum.reduce(valid_answers, 0, fn answer, acc ->
          case answer.metadata do
            %{"word_count" => count} -> acc + count
            _ -> acc + (String.split(answer.text || "") |> length())
          end
        end)

        div(total_length, total)
    end
  end

  @doc """
  Calculate average response time in seconds.
  """
  def calculate_avg_response_time(answers) when is_list(answers) do
    valid_times = answers
      |> Enum.reject(& &1.skipped)
      |> Enum.map(& get_response_time/1)
      |> Enum.reject(&is_nil/1)

    case valid_times do
      [] -> nil
      times ->
        avg = Enum.sum(times) / length(times)
        Float.round(avg, 2)
    end
  end

  @doc """
  Calculate average difficulty rating given by users.
  """
  def calculate_avg_difficulty_rating(answers) when is_list(answers) do
    valid_ratings = answers
      |> Enum.reject(& &1.skipped)
      |> Enum.map(& &1.difficulty_rating)
      |> Enum.reject(&is_nil/1)

    case valid_ratings do
      [] -> nil
      ratings ->
        avg = Enum.sum(ratings) / length(ratings)
        Float.round(avg, 2)
    end
  end

  @doc """
  Calculate completion rate (non-skipped answers).
  """
  def calculate_completion_rate(answers) when is_list(answers) do
    total = length(answers)
    case total do
      0 -> 0.0
      _ ->
        completed = Enum.count(answers, & !&1.skipped)
        Float.round(completed / total * 100, 2)
    end
  end

  @doc """
  Calculate category performance metrics.
  """
  def calculate_category_performance(answers) when is_list(answers) do
    answers
    |> Enum.group_by(& &1.question.category)
    |> Enum.map(fn {category, category_answers} ->
      {category, %{
        total_answers: length(category_answers),
        skip_rate: calculate_skip_rate(category_answers),
        avg_response_time: calculate_avg_response_time(category_answers),
        avg_difficulty_rating: calculate_avg_difficulty_rating(category_answers)
      }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Calculate streak statistics for a user.
  """
  def calculate_streak_stats(user_id) do
    answers = Repo.all(from a in Answer,
      where: a.user_id == ^user_id,
      order_by: [desc: :inserted_at],
      select: %{
        date: fragment("DATE(?)", a.inserted_at),
        skipped: a.skipped
      })

    current_streak = calculate_current_streak(answers)
    longest_streak = calculate_longest_streak(answers)

    %{
      current_streak: current_streak,
      longest_streak: longest_streak,
      total_days_active: length(Enum.uniq_by(answers, & &1.date))
    }
  end

  # Private helpers

  defp get_response_time(%{metadata: %{"response_time" => time}}) when not is_nil(time), do: time
  defp get_response_time(_), do: nil

  defp calculate_current_streak(answers) do
    today = Date.utc_today()

    answers
    |> Enum.reduce_while(0, fn answer, streak ->
      date_diff = Date.diff(today, answer.date)

      cond do
        date_diff > streak -> {:halt, streak}
        not answer.skipped -> {:cont, streak + 1}
        true -> {:halt, streak}
      end
    end)
  end

  defp calculate_longest_streak(answers) do
    answers
    |> Enum.chunk_by(& &1.date)
    |> Enum.reduce({0, 0}, fn chunk, {longest, current} ->
      case Enum.any?(chunk, & &1.skipped) do
        false ->
          new_current = current + 1
          {max(longest, new_current), new_current}
        true ->
          {longest, 0}
      end
    end)
    |> elem(0)
  end
end
