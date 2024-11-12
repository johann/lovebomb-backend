defmodule LovebombWeb.Api.V1.UserController do
  use LovebombWeb, :controller

  alias Lovebomb.Accounts
  alias Lovebomb.Accounts.User
  alias Lovebomb.Guardian

  action_fallback LovebombWeb.FallbackController

  @doc """
  Register a new user.
  POST /api/v1/users/register
  """
  def register(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Accounts.create_user(user_params),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user),
         {:ok, _profile} <- Accounts.create_initial_profile(user.id) do

      conn
      |> put_status(:created)
      |> render(:created, %{user: user, token: token})
    end
  end

  @doc """
  Login an existing user.
  POST /api/v1/users/login
  """
  def login(conn, %{"email" => email, "password" => password}) do
    with {:ok, user} <- Accounts.authenticate_user(email, password),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do

      conn
      |> put_status(:ok)
      |> render(:login, %{user: user, token: token})
    end
  end

  @doc """
  Refresh an authentication token.
  POST /api/v1/users/refresh_token
  """
  def refresh_token(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      conn
      |> put_status(:ok)
      |> render(:token, %{token: token})
    end
  end

  @doc """
  Logout a user (revoke token).
  DELETE /api/v1/users/logout
  """
  def logout(conn, _params) do
    token = Guardian.Plug.current_token(conn)

    with {:ok, _claims} <- Guardian.revoke(token) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Request a password reset.
  POST /api/v1/users/reset_password
  """
  def request_password_reset(conn, %{"email" => email}) do
    with {:ok, user} <- Accounts.get_user_by_email(email),
         {:ok, token} <- Accounts.create_password_reset_token(user),
         :ok <- Lovebomb.Notifications.EmailDelivery.send_password_reset(user, token) do

      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Reset password with token.
  PUT /api/v1/users/reset_password
  """
  def reset_password(conn, %{"token" => token, "password" => password}) do
    with {:ok, user} <- Accounts.verify_password_reset_token(token),
         {:ok, _user} <- Accounts.reset_password(user, password) do

      send_resp(conn, :no_content, "")
    end
  end
end
