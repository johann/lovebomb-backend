defmodule Lovebomb.Notifications.PushDelivery do
  @moduledoc """
  Handles push notification delivery using FCM (Firebase Cloud Messaging).
  Supports both iOS and Android platforms with platform-specific configurations.
  """

  require Logger
  alias Lovebomb.Accounts

  @fcm_url "https://fcm.googleapis.com/fcm/send"
  @retry_attempts 3
  @retry_delay 1_000 # 1 second

  @doc """
  Delivers a push notification to all user's registered devices.
  Handles platform-specific payload formatting and delivery confirmation.
  """
  def deliver_notification(notification) do
    with {:ok, user} <- get_user_with_devices(notification.user_id),
         {:ok, payload} <- build_payload(notification),
         {:ok, responses} <- send_to_devices(user.devices, payload) do

      process_responses(responses, notification)
    else
      {:error, reason} = error ->
        Logger.error("Push delivery failed: #{inspect(reason)}")
        error
    end
  end

  defp get_user_with_devices(user_id) do
    case Accounts.get_user_with_devices(user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp build_payload(notification) do
    base_payload = %{
      "notification" => %{
        "title" => notification.title,
        "body" => notification.body,
        "sound" => "default",
        "badge" => 1,
        "click_action" => get_click_action(notification),
        "tag" => Atom.to_string(notification.type)
      },
      "data" => Map.merge(notification.data, %{
        "notification_id" => notification.id,
        "type" => Atom.to_string(notification.type)
      })
    }

    {:ok, base_payload}
  end

  defp get_click_action(notification) do
    case notification.type do
      :partnership_request -> "OPEN_PARTNERSHIPS"
      :answer_shared -> "OPEN_ANSWER"
      :achievement_unlocked -> "OPEN_ACHIEVEMENTS"
      _ -> "OPEN_APP"
    end
  end

  defp send_to_devices(devices, payload) do
    devices
    |> Enum.group_by(& &1.platform)
    |> Enum.map(fn {platform, platform_devices} ->
      tokens = Enum.map(platform_devices, & &1.token)
      send_platform_specific(platform, tokens, payload)
    end)
    |> handle_responses()
  end

  defp send_platform_specific(platform, tokens, base_payload) do
    platform_payload = customize_for_platform(platform, base_payload)

    tokens
    |> Enum.chunk_every(1000) # FCM limit
    |> Enum.map(&send_batch(&1, platform_payload))
  end

  defp customize_for_platform("ios", payload) do
    put_in(payload, ["notification", "mutable_content"], true)
  end
  defp customize_for_platform("android", payload) do
    put_in(payload, ["notification", "android_channel_id"], "default")
  end
  defp customize_for_platform(_, payload), do: payload

  defp send_batch(tokens, payload) do
    final_payload = Map.put(payload, "registration_ids", tokens)

    retry_with_backoff(fn ->
      Finch.build(:post, @fcm_url, headers(), Jason.encode!(final_payload))
      |> Finch.request(LovebombFinch)
      |> handle_fcm_response()
    end)
  end

  defp retry_with_backoff(func, attempt \\ 1) do
    case func.() do
      {:ok, _} = success -> success
      {:error, reason} ->
        if attempt < @retry_attempts do
          Process.sleep(@retry_delay * attempt)
          retry_with_backoff(func, attempt + 1)
        else
          {:error, reason}
        end
    end
  end

  defp headers do
    [
      {"Authorization", "key=#{fcm_server_key()}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp fcm_server_key do
    Application.get_env(:lovebomb, :fcm_server_key) ||
      raise "FCM server key not configured!"
  end

  defp handle_fcm_response({:ok, %Finch.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, Jason.decode!(body)}
  end
  defp handle_fcm_response({:ok, %Finch.Response{status: status, body: body}}) do
    Logger.error("FCM error: status=#{status}, body=#{body}")
    {:error, "FCM error: #{status}"}
  end
  defp handle_fcm_response({:error, reason} = error) do
    Logger.error("FCM request failed: #{inspect(reason)}")
    error
  end

  defp handle_responses(responses) do
    failures = Enum.filter(responses, &match?({:error, _}, &1))

    if Enum.empty?(failures) do
      {:ok, responses}
    else
      {:error, "Some notifications failed to deliver: #{inspect(failures)}"}
    end
  end

  defp process_responses(responses, notification) do
    # Extract invalid tokens and update user device records
    invalid_tokens = extract_invalid_tokens(responses)

    if invalid_tokens != [] do
      Task.start(fn ->
        Accounts.remove_invalid_devices(invalid_tokens)
      end)
    end

    success_count = count_successful_deliveries(responses)
    Logger.info("Push notification #{notification.id} delivered to #{success_count} devices")

    {:ok, notification}
  end

  defp extract_invalid_tokens(responses) do
    responses
    |> Enum.flat_map(fn
      {:ok, %{"results" => results}} ->
        Enum.with_index(results)
        |> Enum.filter(fn {result, _} ->
          Map.has_key?(result, "error") and
          result["error"] in ["InvalidRegistration", "NotRegistered"]
        end)
        |> Enum.map(fn {_, index} -> index end)
      _ -> []
    end)
  end

  defp count_successful_deliveries(responses) do
    responses
    |> Enum.map(fn
      {:ok, %{"success" => success}} -> success
      _ -> 0
    end)
    |> Enum.sum()
  end
end
