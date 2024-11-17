# lib/lovebomb/notifications/pub_sub.ex

defmodule Lovebomb.PubSub do
  @moduledoc """
  Handles real-time event broadcasting using Phoenix PubSub.
  """

  def broadcast(topic, event, payload) do
    Phoenix.PubSub.broadcast(Lovebomb.PubSub, topic, {event, payload})
  end

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(Lovebomb.PubSub, topic)
  end

  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(Lovebomb.PubSub, topic)
  end

  # Partnership specific broadcasts
  def broadcast_partnership_request(partnership) do
    broadcast(
      "user:#{partnership.partner_id}",
      :partnership_request,
      %{
        partnership_id: partnership.id,
        user_id: partnership.user_id,
        status: partnership.status,
        timestamp: DateTime.utc_now()
      }
    )
    {:ok, partnership}
  end

  def broadcast_partnership_status_change(payload) do
    broadcast("partnerships:#{payload.partnership_id}", :status_changed, payload)
  end

  def broadcast_partnership_interaction(interaction) do
    broadcast(
      "partnerships:#{interaction.partnership_id}",
      :new_interaction,
      interaction
    )
  end

  def broadcast_partnership_settings_update(partnership) do
    broadcast(
      "partnerships:#{partnership.id}",
      :settings_updated,
      partnership
    )
  end

  def broadcast_achievement(user_id, achievement_type, achievement_data) do
    broadcast(
      "user:#{user_id}",
      :achievement_unlocked,
      %{
        type: achievement_type,
        data: achievement_data,
        timestamp: DateTime.utc_now()
      }
    )
  end
end
