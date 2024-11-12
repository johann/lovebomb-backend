defmodule LovebombWeb.ChangesetJSON do
  @moduledoc """
  Renders changeset errors in a consistent format.
  """

  def error(%{changeset: changeset}) do
    %{
      error: %{
        code: "validation_error",
        message: "Invalid parameters",
        details: format_errors(changeset)
      }
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
