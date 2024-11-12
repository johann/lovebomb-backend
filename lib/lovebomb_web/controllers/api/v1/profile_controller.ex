# lib/lovebomb_web/controllers/api/v1/profile_controller.ex
defmodule LovebombWeb.Api.V1.ProfileController do
  use LovebombWeb, :controller

  alias Lovebomb.Accounts
  alias Lovebomb.Accounts.Profile
  alias Lovebomb.Uploaders.Avatar

  action_fallback LovebombWeb.FallbackController

  @doc """
  Get the current user's profile.
  GET /api/v1/profile
  """
  def show(conn, _params) do
    user = conn.assigns.current_user
    profile = Accounts.get_full_profile(user.id)

    conn
    |> put_status(:ok)
    |> render(:show, profile: profile)
  end

  @doc """
  Update the user's profile information.
  PUT /api/v1/profile
  """
  def update(conn, %{"profile" => profile_params}) do
    user = conn.assigns.current_user

    with {:ok, profile} <- Accounts.update_profile(user.id, profile_params) do
      conn
      |> put_status(:ok)
      |> render(:show, profile: profile)
    end
  end

  @doc """
  Upload or update profile avatar.
  POST /api/v1/profile/avatar
  Accepts multipart form data with 'avatar' file field.
  """
  def upload_avatar(conn, %{"avatar" => avatar_params}) do
    user = conn.assigns.current_user

    with {:ok, avatar_url} <- Avatar.store(avatar_params, user),
         {:ok, profile} <- Accounts.update_profile(user.id, %{avatar_url: avatar_url}) do

      conn
      |> put_status(:ok)
      |> render(:avatar, profile: profile)
    end
  end

  @doc """
  Update user's notification preferences.
  PUT /api/v1/profile/preferences
  """
  def update_preferences(conn, %{"preferences" => preferences}) do
    user = conn.assigns.current_user

    with {:ok, profile} <- Accounts.update_notification_preferences(user.id, preferences) do
      conn
      |> put_status(:ok)
      |> render(:preferences, profile: profile)
    end
  end

  @doc """
  Update user's privacy settings.
  PUT /api/v1/profile/privacy
  """
  def update_privacy(conn, %{"privacy" => privacy_settings}) do
    user = conn.assigns.current_user

    with {:ok, profile} <- Accounts.update_privacy_settings(user.id, privacy_settings) do
      conn
      |> put_status(:ok)
      |> render(:privacy, profile: profile)
    end
  end

  @doc """
  Update user's password.
  PUT /api/v1/profile/password
  """
  def update_password(conn, %{"current_password" => current_password, "new_password" => new_password}) do
    user = conn.assigns.current_user

    with {:ok, _user} <- Accounts.update_user_password(user, current_password, new_password) do
      conn
      |> put_status(:ok)
      |> render(:password_updated)
    end
  end

  @doc """
  Get user's activity statistics.
  GET /api/v1/profile/stats
  """
  def stats(conn, params) do
    user = conn.assigns.current_user

    timeframe = Map.get(params, "timeframe", "month")
    stats = Accounts.get_user_stats(user.id, timeframe)

    conn
    |> put_status(:ok)
    |> render(:stats, stats: stats)
  end

  @doc """
  Update user's app settings.
  PUT /api/v1/profile/settings
  """
  def update_settings(conn, %{"settings" => settings}) do
    user = conn.assigns.current_user

    with {:ok, profile} <- Accounts.update_app_settings(user.id, settings) do
      conn
      |> put_status(:ok)
      |> render(:settings, profile: profile)
    end
  end

  @doc """
  Delete user's avatar.
  DELETE /api/v1/profile/avatar
  """
  def delete_avatar(conn, _params) do
    user = conn.assigns.current_user

    with :ok <- Avatar.delete(user),
         {:ok, profile} <- Accounts.update_profile(user.id, %{avatar_url: nil}) do

      conn
      |> put_status(:ok)
      |> render(:avatar, profile: profile)
    end
  end
end

# lib/lovebomb_web/controllers/api/v1/profile_json.ex
defmodule LovebombWeb.Api.V1.ProfileJSON do
  @doc """
  Renders full profile information.
  """
  def show(%{profile: profile}) do
    %{
      data: %{
        id: profile.id,
        display_name: profile.display_name,
        bio: profile.bio,
        avatar_url: profile.avatar_url,
        username: profile.user.username,
        email: profile.user.email,
        created_at: profile.inserted_at,
        stats: %{
          questions_answered: profile.user.questions_answered,
          current_streak: profile.user.streak_days,
          highest_level: profile.user.highest_level,
          partnerships_count: length(profile.user.partnerships)
        },
        preferences: profile.preferences,
        privacy_settings: profile.privacy_settings,
        app_settings: profile.app_settings
      }
    }
  end

  @doc """
  Renders avatar update response.
  """
  def avatar(%{profile: profile}) do
    %{
      data: %{
        avatar_url: profile.avatar_url
      },
      message: "Avatar updated successfully"
    }
  end

  @doc """
  Renders preferences update response.
  """
  def preferences(%{profile: profile}) do
    %{
      data: %{
        preferences: profile.preferences
      },
      message: "Preferences updated successfully"
    }
  end

  @doc """
  Renders privacy settings update response.
  """
  def privacy(%{profile: profile}) do
    %{
      data: %{
        privacy_settings: profile.privacy_settings
      },
      message: "Privacy settings updated successfully"
    }
  end

  @doc """
  Renders password update response.
  """
  def password_updated(_) do
    %{
      data: nil,
      message: "Password updated successfully"
    }
  end

  @doc """
  Renders user statistics.
  """
  def stats(%{stats: stats}) do
    %{
      data: %{
        questions: %{
          total_answered: stats.total_questions,
          skip_rate: stats.skip_rate,
          category_distribution: stats.category_distribution
        },
        streaks: %{
          current_streak: stats.current_streak,
          longest_streak: stats.longest_streak,
          average_streak: stats.average_streak
        },
        activity: %{
          daily_completion_rate: stats.daily_completion_rate,
          active_days: stats.active_days,
          total_interactions: stats.total_interactions
        },
        partnerships: %{
          total_partnerships: stats.total_partnerships,
          average_partnership_level: stats.average_partnership_level,
          total_shared_answers: stats.total_shared_answers
        },
        achievements: stats.achievements
      }
    }
  end

  @doc """
  Renders app settings update response.
  """
  def settings(%{profile: profile}) do
    %{
      data: %{
        app_settings: profile.app_settings
      },
      message: "App settings updated successfully"
    }
  end
end

# lib/lovebomb/uploaders/avatar.ex
defmodule Lovebomb.Uploaders.Avatar do
  @moduledoc """
  Handles avatar file uploads and storage.
  """

  @doc """
  Stores an avatar file for a user.
  """
  def store(upload, user) do
    with {:ok, filename} <- validate_file(upload),
         {:ok, path} <- process_file(upload, filename, user),
         {:ok, url} <- store_file(path, user) do

      cleanup_old_avatar(user)
      {:ok, url}
    end
  end

  @doc """
  Deletes a user's avatar.
  """
  def delete(user) do
    case user.profile.avatar_url do
      nil -> {:ok, nil}
      url -> delete_file(url)
    end
  end

  # Private functions

  defp validate_file(upload) do
    with {:ok, type} <- validate_content_type(upload.content_type),
         :ok <- validate_file_size(upload.path) do
      {:ok, generate_filename(type)}
    end
  end

  defp validate_content_type(content_type) do
    case content_type do
      "image/jpeg" -> {:ok, "jpg"}
      "image/png" -> {:ok, "png"}
      "image/webp" -> {:ok, "webp"}
      _ -> {:error, :invalid_content_type}
    end
  end

  defp validate_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= 5_000_000 -> :ok
      _ -> {:error, :file_too_large}
    end
  end

  defp generate_filename(type) do
    "#{Ecto.UUID.generate()}.#{type}"
  end

  defp process_file(upload, filename, _user) do
    # Process file with image processing library
    # Resize, optimize, etc.
    {:ok, upload.path}
  end

  defp store_file(path, user) do
    # Store file in cloud storage
    # Return public URL
    {:ok, "https://storage.example.com/avatars/#{user.id}/#{Path.basename(path)}"}
  end

  defp cleanup_old_avatar(user) do
    case user.profile.avatar_url do
      nil -> :ok
      url -> delete_file(url)
    end
  end

  defp delete_file(url) do
    # Delete file from cloud storage
    {:ok, url}
  end
end
