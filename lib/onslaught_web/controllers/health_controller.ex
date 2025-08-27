defmodule OnslaughtWeb.HealthController do
  use OnslaughtWeb, :controller

  def check(conn, _params) do
    conn
    |> put_status(:ok)
    |> text("OK")
  end
end
