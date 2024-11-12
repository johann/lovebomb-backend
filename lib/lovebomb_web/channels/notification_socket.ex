defmodule LovebombWeb.NotificationSocket do
  use Phoenix.Socket

  channel "notifications:*", LovebombWeb.NotificationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Lovebomb.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        {:ok, assign(socket, :user_id, claims["sub"])}
      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def id(socket), do: "notifications_socket:#{socket.assigns.user_id}"
end
