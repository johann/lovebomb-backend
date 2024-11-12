defmodule Lovebomb.Notifications.EmailDelivery do
  @moduledoc """
  Handles email notification delivery using Swoosh.
  Provides templated emails for different notification types.
  """

  use Swoosh.Mailer, otp_app: :lovebomb
  import Swoosh.Email
  require Logger

  @doc """
  Delivers an email notification based on the notification type and template.
  """
  def deliver_notification(notification) do
    notification = Lovebomb.Repo.preload(notification, [:user, :actor])

    email =
      new()
      |> to({notification.user.profile.display_name, notification.user.email})
      |> from({"LoveBomb", "notifications@lovebomb.app"})
      |> subject(get_subject(notification))
      |> html_body(render_email_template(notification))
      |> text_body(render_text_template(notification))
      |> maybe_add_attachments(notification)

    case deliver(email) do
      {:ok, _response} ->
        Logger.info("Email delivered successfully for notification: #{notification.id}")
        {:ok, notification}
      {:error, reason} = error ->
        Logger.error("Email delivery failed for notification: #{notification.id}, reason: #{inspect(reason)}")
        error
    end
  end

  defp get_subject(notification) do
    base_subject = case notification.type do
      :partnership_request -> "New Partnership Request"
      :partnership_accepted -> "Partnership Request Accepted"
      :answer_shared -> "New Answer Shared"
      :achievement_unlocked -> "Achievement Unlocked!"
      :streak_milestone -> "Streak Milestone Reached!"
      :level_up -> "Level Up!"
      :daily_reminder -> "Your Daily Question Awaits"
      :partner_milestone -> "Your Partner Reached a Milestone!"
      _ -> notification.title
    end

    if notification.actor do
      "#{notification.actor.profile.display_name} - #{base_subject}"
    else
      base_subject
    end
  end

  defp render_email_template(notification) do
    Phoenix.View.render_to_string(
      LovebombWeb.EmailView,
      "#{notification.type}.html",
      notification: notification
    )
  rescue
    _error ->
      Logger.warning("Failed to render custom template for #{notification.type}, using default")
      render_default_template(notification)
  end

  defp render_text_template(notification) do
    Phoenix.View.render_to_string(
      LovebombWeb.EmailView,
      "#{notification.type}.text",
      notification: notification
    )
  rescue
    _error ->
      notification.body
  end

  defp render_default_template(notification) do
    """
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>#{notification.title}</title>
      </head>
      <body>
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1>#{notification.title}</h1>
          <p>#{notification.body}</p>
          #{render_notification_data(notification)}
        </div>
      </body>
    </html>
    """
  end

  defp render_notification_data(notification) do
    case notification.data do
      %{} = data when map_size(data) == 0 -> ""
      data ->
        """
        <div style="margin-top: 20px; padding: 10px; background: #f5f5f5; border-radius: 5px;">
          #{render_data_details(data)}
        </div>
        """
    end
  end

  defp render_data_details(data) do
    data
    |> Enum.map(fn {key, value} ->
      "<p><strong>#{Phoenix.Naming.humanize(key)}:</strong> #{value}</p>"
    end)
    |> Enum.join("\n")
  end

  defp maybe_add_attachments(email, notification) do
    case notification.data do
      %{"attachments" => attachments} when is_list(attachments) ->
        Enum.reduce(attachments, email, &add_attachment(&2, &1))
      _ ->
        email
    end
  end

  defp add_attachment(email, %{"url" => url, "filename" => filename}) do
    attachment(email, %{url: url, filename: filename})
  end
  defp add_attachment(email, _), do: email
end
