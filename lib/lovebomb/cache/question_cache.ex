# lib/lovebomb/cache/question_cache.ex
defmodule Lovebomb.Cache.QuestionCache do
  use GenServer
  require Logger

  @table_name :question_cache

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expiry}] ->
        if DateTime.compare(expiry, DateTime.utc_now()) == :gt do
          value
        else
          :ets.delete(@table_name, key)
          nil
        end
      [] -> nil
    end
  end

  def put(key, value, ttl_seconds \\ 86400) do
    expiry = DateTime.add(DateTime.utc_now(), ttl_seconds, :second)
    :ets.insert(@table_name, {key, value, expiry})
    value
  end

  def delete(key) do
    :ets.delete(@table_name, key)
  end

  def clear do
    :ets.delete_all_objects(@table_name)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("Starting QuestionCache")
    table = :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true])
    {:ok, table}
  end

  @impl true
  def handle_info(:cleanup, table) do
    now = DateTime.utc_now()

    # Delete expired entries
    :ets.match_object(@table_name, {:"$1", :"$2", :"$3"})
    |> Enum.each(fn {key, _value, expiry} ->
      if DateTime.compare(expiry, now) == :lt do
        :ets.delete(@table_name, key)
      end
    end)

    schedule_cleanup()
    {:noreply, table}
  end

  # Private Functions

  defp schedule_cleanup do
    # Run cleanup every hour
    Process.send_after(self(), :cleanup, :timer.hours(1))
  end
end
