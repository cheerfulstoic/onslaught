defmodule Onslaught.Repo do
  use Ecto.Repo,
    otp_app: :onslaught,
    adapter: Ecto.Adapters.Postgres
end
