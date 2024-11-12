defmodule LovebombWeb.Api.V1.UserJSON do
  @doc """
  Renders user on successful registration.
  """
  def created(%{user: user, token: token}) do
    %{
      data: %{
        id: user.id,
        email: user.email,
        username: user.username,
        token: token
      },
      message: "Registration successful"
    }
  end

  @doc """
  Renders user on successful login.
  """
  def login(%{user: user, token: token}) do
    %{
      data: %{
        id: user.id,
        email: user.email,
        username: user.username,
        token: token
      },
      message: "Login successful"
    }
  end

  @doc """
  Renders new token on refresh.
  """
  def token(%{token: token}) do
    %{
      data: %{
        token: token
      }
    }
  end
end
