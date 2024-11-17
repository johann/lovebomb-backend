# test/lovebomb/accounts/partnership_test.exs
defmodule Lovebomb.Accounts.PartnershipTest do
  use Lovebomb.DataCase, async: true

  alias Lovebomb.Accounts.Partnership
  alias Lovebomb.Accounts

  import Lovebomb.AccountsFixtures

  describe "partnerships" do
    setup do
      user = user_fixture()
      partner = user_fixture()
      valid_attrs = valid_partnership_attributes(%{user: user, partner: partner})

      {:ok, user: user, partner: partner, valid_attrs: valid_attrs}
    end

    test "create_partnership/1 with valid data creates bidirectional partnerships",
      %{valid_attrs: valid_attrs} do
      assert {:ok, partnership} = Accounts.create_partnership(valid_attrs)
      assert partnership.status == :pending

      # Verify reverse partnership was created
      reverse_partnership = Repo.get_by!(Partnership,
        user_id: valid_attrs.partner_id,
        partner_id: valid_attrs.user_id
      )
      assert reverse_partnership.status == :pending
    end

    test "create_partnership/1 with invalid data returns error changeset",
      %{user: user} do
      # Missing partner_id
      invalid_attrs = %{user_id: user.id, status: :pending}
      assert {:error, %Ecto.Changeset{}} = Accounts.create_partnership(invalid_attrs)

      # Both fields missing
      assert {:error, %Ecto.Changeset{}} = Accounts.create_partnership(%{})

      # Only status provided
      assert {:error, %Ecto.Changeset{}} = Accounts.create_partnership(%{status: :pending})
    end

    test "cannot create partnership with self",
      %{user: user, valid_attrs: attrs} do
      invalid_attrs = %{attrs | partner_id: user.id}
      assert {:error, changeset} = Accounts.create_partnership(invalid_attrs)
      assert "cannot create partnership with yourself" in errors_on(changeset).partner_id
    end

    test "cannot create duplicate partnership",
      %{valid_attrs: attrs} do
      assert {:ok, _} = Accounts.create_partnership(attrs)
      assert {:error, :partnership_exists} = Accounts.create_partnership(attrs)
    end
  end

  describe "partnership status updates" do
    setup do
      user = user_fixture()
      partner = user_fixture()
      {:ok, partnership} = Accounts.create_partnership(
        valid_partnership_attributes(%{user: user, partner: partner})
      )

      {:ok, partnership: partnership}
    end

    test "update_partnership_status/2 updates both partnerships",
      %{partnership: partnership} do
      assert {:ok, updated} = Accounts.update_partnership_status(partnership, :active)
      assert updated.status == :active

      # Verify reverse partnership was also updated
      reverse = Repo.get_by!(Partnership,
        user_id: partnership.partner_id,
        partner_id: partnership.user_id
      )
      assert reverse.status == :active
    end
  end
end
