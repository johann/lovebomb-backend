defmodule LovebombWeb.ErrorJSON do
  @moduledoc """
  Renders error responses in a consistent format.
  """

  def render("401.json", _assigns) do
    %{
      error: %{
        code: "unauthorized",
        message: "Authentication required"
      }
    }
  end

  def render("403.json", _assigns) do
    %{
      error: %{
        code: "forbidden",
        message: "You don't have permission to perform this action"
      }
    }
  end

  def render("404.json", _assigns) do
    %{
      error: %{
        code: "not_found",
        message: "The requested resource was not found"
      }
    }
  end

  def render("422.json", %{changeset: changeset}) do
    %{
      error: %{
        code: "unprocessable_entity",
        message: "Validation failed",
        details: format_changeset_errors(changeset)
      }
    }
  end

  def render("429.json", _assigns) do
    %{
      error: %{
        code: "rate_limit_exceeded",
        message: "Too many requests. Please try again later."
      }
    }
  end

  def render("500.json", _assigns) do
    %{
      error: %{
        code: "internal_server_error",
        message: "An internal server error occurred"
      }
    }
  end

  def render("error.json", %{message: message}) do
    %{
      error: %{
        code: "error",
        message: message
      }
    }
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
