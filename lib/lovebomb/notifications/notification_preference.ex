defmodule Lovebomb.Notifications.NotificationPreference do
  @moduledoc """
  Schema for user notification preferences.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notification_preferences" do
    field :channel_email, :boolean, default: true
    field :channel_push, :boolean, default: true
    field :channel_in_app, :boolean, default: true

    # Notification type preferences
    field :preferences, :map, default: %{
      "partnership_request" => %{"enabled" => true, "channels" => ["email", "push", "in_app"]},
      "partnership_accepted" => %{"enabled" => true, "channels" => ["email", "push", "in_app"]},
      "partnership_declined" => %{"enabled" => true, "channels" => ["email", "push", "in_app"]},
      "answer_shared" => %{"enabled" => true, "channels" => ["push", "in_app"]},
      "answer_reaction" => %{"enabled" => true, "channels" => ["push", "in_app"]},
      "achievement_unlocked" => %{"enabled" => true, "channels" => ["email", "push", "in_app"]},
      "streak_milestone" => %{"enabled" => true, "channels" => ["push", "in_app"]},
      "level_up" => %{"enabled" => true, "channels" => ["push", "in_app"]},
      "daily_reminder" => %{"enabled" => true, "channels" => ["push"]},
      "partner_milestone" => %{"enabled" => true, "channels" => ["push", "in_app"]}
    }

    # Quiet hours
    field :quiet_hours_enabled, :boolean, default: false
    field :quiet_hours_start, :time
    field :quiet_hours_end, :time
    field :timezone, :string

    belongs_to :user, Lovebomb.Accounts.User

    timestamps()
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:channel_email, :channel_push, :channel_in_app, :preferences,
                    :quiet_hours_enabled, :quiet_hours_start, :quiet_hours_end,
                    :timezone, :user_id])
    |> validate_required([:user_id])
    |> validate_preferences()
    |> validate_timezone()
  end

  defp validate_preferences(changeset) do
    case get_change(changeset, :preferences) do
      nil -> changeset
      preferences ->
        if valid_preferences_structure?(preferences) do
          changeset
        else
          add_error(changeset, :preferences, "has invalid structure")
        end
    end
  end

  defp valid_preferences_structure?(preferences) do
    required_keys = ["enabled", "channels"]
    Enum.all?(preferences, fn {_type, settings} ->
      Enum.all?(required_keys, &Map.has_key?(settings, &1))
    end)
  end

  defp validate_timezone(changeset) do
    case get_change(changeset, :timezone) do
      nil -> changeset
      timezone ->
        if Tzdata.zone_exists?(timezone) do
          changeset
        else
          add_error(changeset, :timezone, "is not a valid timezone")
        end
    end
  end
end
