defmodule Lovebomb.Questions.Answer do
  @moduledoc """
  Schema and changeset for user answers to questions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "answers" do
    field :text, :string
    field :skipped, :boolean, default: false
    field :skip_reason, :string
    field :visibility, Ecto.Enum, values: [:partners_only, :public], default: :partners_only
    field :reactions, {:array, :string}, default: []
    field :difficulty_rating, :integer

    # Response metadata
    field :metadata, :map, default: %{
      "response_time" => nil,
      "edited_count" => 0,
      "last_edited_at" => nil,
      "word_count" => 0,
      "language" => "en"
    }

    belongs_to :user, Lovebomb.Accounts.User
    belongs_to :question, Lovebomb.Questions.Question
    belongs_to :partnership, Lovebomb.Accounts.Partnership

    timestamps()
  end

def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:text, :skipped, :skip_reason, :visibility, :reactions,
                    :difficulty_rating, :metadata, :user_id, :question_id,
                    :partnership_id])
    |> validate_required([:user_id, :question_id])
    |> validate_skip()
    |> validate_length(:text, max: 2000)
    |> validate_inclusion(:difficulty_rating, 1..10)
    |> validate_metadata()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:question_id)
    |> foreign_key_constraint(:partnership_id)
  end

  defp validate_skip(changeset) do
    if get_field(changeset, :skipped) do
      validate_required(changeset, [:skip_reason])
    else
      validate_required(changeset, [:text])
    end
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
    required_keys = ["response_time", "edited_count", "last_edited_at",
                    "word_count", "language"]
    Enum.all?(required_keys, &Map.has_key?(metadata, &1))
  end
end
