defmodule Lovebomb.Repo do
  use Ecto.Repo,
    otp_app: :lovebomb,
    adapter: Ecto.Adapters.Postgres
end
