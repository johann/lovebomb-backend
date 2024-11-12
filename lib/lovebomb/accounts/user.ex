defmodule Lovebomb.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :current_score, :integer, default: 0
    field :highest_level, :integer, default: 1
    field :questions_answered, :integer, default: 0
    field :streak_days, :integer, default: 0
    field :last_answer_date, :date

    has_one :profile, Lovebomb.Accounts.Profile
    has_many :partnerships, Lovebomb.Accounts.Partnership
    has_many :partners, through: [:partnerships, :partner]
    has_many :answers, Lovebomb.Questions.Answer

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end
  defp put_password_hash(changeset), do: changeset
end


# priv/repo/migrations/TIMESTAMP_add_active_and_level_to_users.exs
# defmodule Lovebomb.Repo.Migrations.AddActiveAndLevelToUsers do
#   use Ecto.Migration

#   def change do
#     alter table(:users, primary_key: false) do
#       add :active, :boolean, default: true
#       add :level, :integer, default: 1
#     end
#   end
# end


# defmodule Lovebomb.Accounts.User do
#   use Ecto.Schema
#   import Ecto.Changeset

#   @primary_key {:id, :binary_id, autogenerate: true}
#   @foreign_key_type :binary_id
#   schema "users" do
#     field :username, :string
#     field :email, :string
#     field :password, :string, virtual: true
#     field :password_hash, :string
#     field :active, :boolean, default: true
#     field :level, :integer, default: 1
#     field :current_score, :integer, default: 0
#     field :highest_level, :integer, default: 1
#     field :questions_answered, :integer, default: 0
#     field :streak_days, :integer, default: 0
#     field :last_answer_date, :date

#     has_one :profile, Lovebomb.Accounts.Profile
#     has_many :partnerships, Lovebomb.Accounts.Partnership
#     has_many :partners, through: [:partnerships, :partner]
#     has_many :answers, Lovebomb.Questions.Answer

#     timestamps()
#   end

#   def changeset(user, attrs) do
#     user
#     |> cast(attrs, [:username, :email, :password, :active, :level])
#     |> validate_required([:username, :email, :password])
#     |> validate_length(:username, min: 3, max: 30)
#     |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
#     |> validate_number(:level, greater_than_or_equal_to: 1)
#     |> unique_constraint(:email)
#     |> unique_constraint(:username)
#     |> put_password_hash()
#   end

#   @doc """
#   Changeset for updating user statistics.
#   """
#   def stats_changeset(user, attrs) do
#     user
#     |> cast(attrs, [
#       :questions_answered,
#       :streak_days,
#       :last_answer_date,
#       :level,
#       :highest_level,
#       :current_score
#     ])
#     |> validate_required([:questions_answered, :streak_days])
#     |> validate_number(:questions_answered, greater_than_or_equal_to: 0)
#     |> validate_number(:streak_days, greater_than_or_equal_to: 0)
#     |> validate_number(:level, greater_than_or_equal_to: 1)
#     |> validate_number(:highest_level, greater_than_or_equal_to: 1)
#     |> validate_number(:current_score, greater_than_or_equal_to: 0)
#     |> update_highest_level()
#   end

#   defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
#     put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
#   end
#   defp put_password_hash(changeset), do: changeset

#   defp update_highest_level(changeset) do
#     case {get_change(changeset, :level), get_field(changeset, :highest_level)} do
#       {nil, _} -> changeset
#       {new_level, highest_level} when new_level > highest_level ->
#         put_change(changeset, :highest_level, new_level)
#       _ -> changeset
#     end
#   end
# end


# lib/lovebomb/questions/question.ex
# defmodule Lovebomb.Questions.Question do
#   use Ecto.Schema
#   import Ecto.Changeset

#   @primary_key {:id, :binary_id, autogenerate: true}
#   @foreign_key_type :binary_id
#   schema "questions" do
#     field :content, :string
#     field :category, :string
#     field :difficulty_level, :integer
#     field :min_level, :integer
#     field :max_level, :integer
#     field :active, :boolean, default: true
#     field :repeat_after_days, :integer
#     field :stats, :map, default: %{}

#     has_many :answers, Lovebomb.Questions.Answer

#     timestamps()
#   end

#   def changeset(question, attrs) do
#     question
#     |> cast(attrs, [
#       :content,
#       :category,
#       :difficulty_level,
#       :min_level,
#       :max_level,
#       :active,
#       :repeat_after_days
#     ])
#     |> validate_required([:content, :category, :difficulty_level])
#     |> validate_number(:difficulty_level, greater_than_or_equal_to: 1)
#     |> validate_number(:min_level, greater_than_or_equal_to: 1)
#     |> validate_inclusion(:category, ["relationship", "personal", "future", "past", "values", "fun"])
#   end

#   def stats_changeset(question, attrs) do
#     question
#     |> cast(attrs, [:stats])
#     |> validate_required([:stats])
#   end
# end

# mix ecto.gen.migration create_questions

# priv/repo/migrations/TIMESTAMP_create_questions.exs
# defmodule Lovebomb.Repo.Migrations.CreateQuestions do
#   use Ecto.Migration

#   def change do
#     create table(:questions, primary_key: false) do
#       add :id, :binary_id, primary_key: true
#       add :content, :text, null: false
#       add :category, :string, null: false
#       add :difficulty_level, :integer, null: false
#       add :min_level, :integer
#       add :max_level, :integer
#       add :active, :boolean, default: true
#       add :repeat_after_days, :integer
#       add :stats, :map, default: %{}

#       timestamps()
#     end

#     create index(:questions, [:category])
#     create index(:questions, [:difficulty_level])
#   end
# end

# lib/lovebomb/questions/answer.ex
# defmodule Lovebomb.Questions.Answer do
#   use Ecto.Schema
#   import Ecto.Changeset

#   @primary_key {:id, :binary_id, autogenerate: true}
#   @foreign_key_type :binary_id
#   schema "answers" do
#     field :content, :string
#     field :skipped, :boolean, default: false
#     field :skip_reason, :string
#     field :difficulty_rating, :integer
#     field :answered_at, :utc_datetime

#     belongs_to :user, Lovebomb.Accounts.User, type: :binary_id
#     belongs_to :question, Lovebomb.Questions.Question, type: :binary_id
#     belongs_to :partnership, Lovebomb.Accounts.Partnership, type: :binary_id

#     timestamps()
#   end

#   def changeset(answer, attrs) do
#     answer
#     |> cast(attrs, [
#       :content,
#       :skipped,
#       :skip_reason,
#       :difficulty_rating,
#       :answered_at,
#       :user_id,
#       :question_id,
#       :partnership_id
#     ])
#     |> validate_required([:user_id, :question_id])
#     |> validate_skip()
#     |> validate_number(:difficulty_rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
#   end

#   defp validate_skip(changeset) do
#     if get_field(changeset, :skipped) do
#       validate_required(changeset, [:skip_reason])
#     else
#       validate_required(changeset, [:content])
#     end
#   end
# end

# mix ecto.gen.migration create_answers

# priv/repo/migrations/TIMESTAMP_create_answers.exs
# defmodule Lovebomb.Repo.Migrations.CreateAnswers do
#   use Ecto.Migration

#   def change do
#     create table(:answers, primary_key: false) do
#       add :id, :binary_id, primary_key: true
#       add :content, :text
#       add :skipped, :boolean, default: false
#       add :skip_reason, :string
#       add :difficulty_rating, :integer
#       add :answered_at, :utc_datetime
#       add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
#       add :question_id, references(:questions, type: :binary_id, on_delete: :delete_all)
#       add :partnership_id, references(:partnerships, type: :binary_id, on_delete: :nilify_all)

#       timestamps()
#     end

#     create index(:answers, [:user_id])
#     create index(:answers, [:question_id])
#     create index(:answers, [:partnership_id])
#   end
# end
