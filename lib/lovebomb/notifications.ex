defmodule Lovebomb.Notifications do
  @moduledoc """
  The Notifications context handles notification management and delivery.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias Lovebomb.Repo
  alias Lovebomb.Notifications.{Notification, NotificationPreference}
  alias Lovebomb.PubSub
  alias Lovebomb.Notifications.{EmailDelivery, PushDelivery}

  # Notification Creation and Management

  @doc """
  Creates a notification and delivers it through appropriate channels
  based on user preferences.
  """
  def create_notification(attrs) do
    Multi.new()
    |> Multi.run(:preferences, fn repo, _ ->
      {:ok, repo.get_by!(NotificationPreference, user_id: attrs.user_id)}
    end)
    |> Multi.run(:check_quiet_hours, fn _repo, %{preferences: prefs} ->
      if should_deliver_now?(prefs) do
        {:ok, true}
      else
        {:ok, false}
      end
    end)
    |> Multi.insert(:notification, fn _ ->
      Notification.changeset(%Notification{}, attrs)
    end)
    |> Multi.run(:deliver, fn _repo, %{notification: notif, preferences: prefs, check_quiet_hours: deliver} ->
      if deliver do
        deliver_notification(notif, prefs)
      else
        {:ok, :quiet_hours}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{notification: notification}} -> {:ok, notification}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Lists notifications for a user with filtering and pagination.
  """
  def list_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    type = Keyword.get(opts, :type)
    read = Keyword.get(opts, :read)

    Notification
    |> where([n], n.user_id == ^user_id)
    |> filter_by_type(type)
    |> filter_by_read(read)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Marks notifications as read.
  """
  def mark_as_read(notification_ids) when is_list(notification_ids) do
    now = DateTime.utc_now()

    Notification
    |> where([n], n.id in ^notification_ids)
    |> update(set: [read: true, read_at: ^now])
    |> Repo.update_all([])
  end

  @doc """
  Updates notification preferences for a user.
  """
  def update_preferences(user_id, attrs) do
    NotificationPreference
    |> Repo.get_by!(user_id: user_id)
    |> NotificationPreference.changeset(attrs)
    |> Repo.update()
  end

  # Real-time notifications via PubSub

  @doc """
  Broadcasts a real-time notification to a specific user.
  """
  def broadcast_to_user(user_id, event, payload) do
    PubSub.broadcast("user:#{user_id}", event, payload)
  end

  @doc """
  Broadcasts a partnership event to both users involved.
  """
  def broadcast_partnership_event(partnership, event, payload) do
    PubSub.broadcast("user:#{partnership.user_id}", event, payload)
    PubSub.broadcast("user:#{partnership.partner_id}", event, payload)
  end

  # Private Functions

  defp filter_by_type(query, nil), do: query
  defp filter_by_type(query, type) do
    where(query, [n], n.type == ^type)
  end

  defp filter_by_read(query, nil), do: query
  defp filter_by_read(query, read) do
    where(query, [n], n.read == ^read)
  end

  defp should_deliver_now?(preferences) do
    if preferences.quiet_hours_enabled do
      current_time = DateTime.now!(preferences.timezone)
      not in_quiet_hours?(current_time, preferences.quiet_hours_start, preferences.quiet_hours_end)
    else
      true
    end
  end

  defp in_quiet_hours?(current_time, start_time, end_time) do
    current = Time.from_datetime(current_time)
    Time.compare(current, start_time) == :gt and Time.compare(current, end_time) == :lt
  end

  defp deliver_notification(notification, preferences) do
    enabled_channels = get_enabled_channels(notification.type, preferences)

    Multi.new()
    |> deliver_to_channels(notification, enabled_channels)
    |> Repo.transaction()
  end

  defp get_enabled_channels(type, preferences) do
    case preferences.preferences[Atom.to_string(type)] do
      %{"enabled" => true, "channels" => channels} -> channels
      _ -> []
    end
  end

  defp deliver_to_channels(multi, notification, channels) do
    Enum.reduce(channels, multi, fn channel, multi ->
      case channel do
        "email" -> Multi.run(multi, {:email, notification.id}, fn _, _ ->
          EmailDelivery.deliver_notification(notification)
        end)
        "push" -> Multi.run(multi, {:push, notification.id}, fn _, _ ->
          PushDelivery.deliver_notification(notification)
        end)
        "in_app" -> Multi.run(multi, {:in_app, notification.id}, fn _, _ ->
          broadcast_to_user(notification.user_id, "new_notification", notification)
          {:ok, notification}
        end)
        _ -> multi
      end
    end)
  end
end
