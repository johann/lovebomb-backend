defmodule LovebombWeb.NotificationChannel do
  use Phoenix.Channel
  alias Lovebomb.Notifications

  def join("notifications:" <> user_id, _params, socket) do
    if socket.assigns.user_id == user_id do
      Notifications.subscribe("user:#{user_id}")
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("mark_read", %{"ids" => notification_ids}, socket) do
    Notifications.mark_as_read(notification_ids)
    {:reply, :ok, socket}
  end

  def handle_info({event, payload}, socket) do
    push(socket, Atom.to_string(event), payload)
    {:noreply, socket}
  end
end
