defmodule LovebombWeb.FallbackController do
  use LovebombWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: LovebombWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: LovebombWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: LovebombWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: LovebombWeb.ErrorJSON)
    |> render(:error, message: "Invalid email or password")
  end

  def call(conn, {:error, :invalid_token}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: LovebombWeb.ErrorJSON)
    |> render(:error, message: "Invalid or expired token")
  end
end
