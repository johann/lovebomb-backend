defmodule Lovebomb.TestHelpers do
  def insert_interaction_for_date(partnership, date) do
    {:ok, datetime} = date
      |> NaiveDateTime.new(~T[12:00:00])
      |> DateTime.from_naive("Etc/UTC")

    attrs = %{
      interaction_type: :message,
      content: %{text: "Test message"},
      inserted_at: datetime
    }

    Lovebomb.Accounts.record_interaction(partnership.id, attrs)
  end
end
