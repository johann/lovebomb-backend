# lib/lovebomb_web/plugs/rate_limit.ex
defmodule LovebombWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug using ExRated.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    case check_rate_limit(conn, opts) do
      {:ok, _count} ->
        conn
      {:error, _count} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{
            error: %{
              code: "rate_limit_exceeded",
              message: "Too many requests. Please try again later."
            }
          }))
        |> halt()
    end
  end

  defp check_rate_limit(conn, opts) do
    interval_seconds = opts[:interval_seconds] || 60
    max_requests = opts[:max_requests] || 100

    bucket = bucket_name(conn)
    ExRated.check_rate(bucket, interval_seconds * 1000, max_requests)
  end

  defp bucket_name(conn) do
    # Use IP address for non-authenticated requests, user ID for authenticated ones
    case Guardian.Plug.current_resource(conn) do
      nil ->
        ip = format_ip(conn.remote_ip)
        "ip:#{ip}"
      user ->
        "user:#{user.id}"
    end
  end

  defp format_ip(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end
end
