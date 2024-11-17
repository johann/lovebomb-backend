# test/support/fixtures/accounts_fixtures.ex
defmodule Lovebomb.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lovebomb.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def unique_username, do: "user#{System.unique_integer()}"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      username: unique_username(),
      password: "hello world!"
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Lovebomb.Accounts.create_user()

    user
  end

  def valid_partnership_attributes(%{user: user, partner: partner}) do
    %{
      user_id: user.id,
      partner_id: partner.id,
      status: :pending,
      partnership_level: 1
    }
  end

  def partnership_fixture(context) do
    attrs = valid_partnership_attributes(context)
    {:ok, partnership} = Lovebomb.Accounts.create_partnership(attrs)
    partnership
  end
end
