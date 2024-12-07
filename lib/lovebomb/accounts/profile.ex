defmodule Lovebomb.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "profiles" do
    field :display_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :preferences, :map, default: %{}

    belongs_to :user, Lovebomb.Accounts.User, type: :binary_id

    timestamps()
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:display_name, :bio, :avatar_url, :preferences, :user_id])
    |> validate_required([:display_name, :user_id])
    |> ensure_string_keys_in_preferences()
  end

  defp ensure_string_keys_in_preferences(changeset) do
    case get_change(changeset, :preferences) do
      nil -> changeset
      preferences ->
        string_keyed_prefs = for {key, value} <- preferences, into: %{} do
          {to_string(key), value}
        end
        put_change(changeset, :preferences, string_keyed_prefs)
    end
  end
end
