ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Lovebomb.Repo, :manual)
Application.put_env(:ex_machina, :json_library, Jason)
{:ok, _} = Application.ensure_all_started(:ex_machina)
