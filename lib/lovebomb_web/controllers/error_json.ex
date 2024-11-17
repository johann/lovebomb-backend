defmodule LovebombWeb.ErrorJSON do
  @moduledoc """
  Renders error responses in a consistent format.
  """

  def render("404.json", _assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  def render("401.json", _assigns) do
    %{errors: %{detail: "Unauthorized"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden"}}
  end

  def render("422.json", %{changeset: changeset}) do
    %{errors: %{
      detail: "Unprocessable Entity",
      fields: format_changeset_errors(changeset)
    }}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal Server Error"}}
  end

  # Format changeset errors into a more user-friendly format
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
