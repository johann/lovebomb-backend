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
end
