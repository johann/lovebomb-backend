defmodule Lovebomb.Notifications.Notification do
  @moduledoc """
  Schema for persisted notifications.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :type, Ecto.Enum, values: [
      :partnership_request,
      :partnership_accepted,
      :partnership_declined,
      :answer_shared,
      :answer_reaction,
      :achievement_unlocked,
      :streak_milestone,
      :level_up,
      :daily_reminder,
      :partner_milestone
    ]

    field :title, :string
    field :body, :string
    field :data, :map, default: %{}
    field :read, :boolean, default: false
    field :read_at, :utc_datetime
    field :priority, Ecto.Enum, values: [:low, :normal, :high], default: :normal
    field :expires_at, :utc_datetime

    belongs_to :user, Lovebomb.Accounts.User
    belongs_to :actor, Lovebomb.Accounts.User, foreign_key: :actor_id

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :title, :body, :data, :read, :read_at,
                    :priority, :expires_at, :user_id, :actor_id])
    |> validate_required([:type, :title, :body, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
    |> validate_expiration()
  end

  defp validate_expiration(changeset) do
    case get_change(changeset, :expires_at) do
      nil -> changeset
      expires_at ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
          changeset
        else
          add_error(changeset, :expires_at, "must be in the future")
        end
    end
  end
end
