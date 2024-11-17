defmodule Lovebomb.PubSubTestHelper do
  @moduledoc """
  Test helpers for PubSub functionality.
  """

  def subscribe_and_await_message(topic) do
    Lovebomb.PubSub.subscribe(topic)
    receive do
      {event, payload} -> {event, payload}
    after
      1000 -> {:error, :timeout}
    end
  end
end
