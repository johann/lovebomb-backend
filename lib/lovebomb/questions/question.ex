defmodule Lovebomb.Questions.Question do
  @moduledoc """
  Schema and changeset for questions in the system.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "questions" do
    field :text, :string
    field :difficulty_level, :integer
    field :score_value, :integer
    field :category, :string
    field :tags, {:array, :string}
    field :active, :boolean, default: true
    field :language, :string, default: "en"
    field :author_type, :string, default: "system"

    # Additional metadata
    field :metadata, :map, default: %{
      "followup_questions" => [],
      "suggested_topics" => [],
      "emotional_tags" => [],
      "time_estimate" => "5m"
    }

    # Stats tracking
    field :stats, :map, default: %{
      "times_asked" => 0,
      "skip_rate" => 0.0,
      "avg_response_length" => 0,
      "avg_difficulty_rating" => 0.0,
      "category_performance" => %{}
    }

    has_many :answers, Lovebomb.Questions.Answer
    timestamps()
  end

  def changeset(question, attrs) do
    question
    |> cast(attrs, [:text, :difficulty_level, :score_value, :category, :tags,
                    :active, :language, :author_type, :metadata, :stats])
    |> validate_required([:text, :difficulty_level, :score_value, :category])
    |> validate_inclusion(:difficulty_level, 1..100)
    |> validate_inclusion(:score_value, 1..1000)
    |> validate_length(:text, min: 10, max: 500)
    |> validate_metadata()
    |> validate_stats()
  end

  defp validate_metadata(changeset) do
    case get_change(changeset, :metadata) do
      nil -> changeset
      metadata ->
        if valid_metadata_structure?(metadata) do
          changeset
        else
          add_error(changeset, :metadata, "has invalid structure")
        end
    end
  end

  defp valid_metadata_structure?(metadata) do
    required_keys = ["followup_questions", "suggested_topics", "emotional_tags", "time_estimate"]
    Enum.all?(required_keys, &Map.has_key?(metadata, &1))
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
    required_keys = ["times_asked", "skip_rate", "avg_response_length",
                    "avg_difficulty_rating", "category_performance"]
    Enum.all?(required_keys, &Map.has_key?(stats, &1))
  end
end
