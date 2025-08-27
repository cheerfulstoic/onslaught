defmodule Onslaught.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    setup_opentelemetry()

    children = [
      OnslaughtWeb.Telemetry,
      # Onslaught.Repo,
      {DNSCluster, query: Application.get_env(:onslaught, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Onslaught.PubSub},
      OnslaughtWeb.Endpoint,
      Onslaught.SpawnerSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Onslaught.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp setup_opentelemetry do
    # coveralls-ignore-start
    if Application.get_env(:opentelemetry, :span_processor) do
      :ok = OpentelemetryBandit.setup()
      :ok = OpentelemetryPhoenix.setup(adapter: :bandit)
    end

    # coveralls-ignore-stop
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OnslaughtWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
