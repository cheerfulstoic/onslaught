defmodule Onslaught.SpawnerSupervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @impl true
  def init(_) do
    children = [
      {Phoenix.PubSub, name: Onslaught.SpawnerPubSub},
      Onslaught.Spawner.Metrics,
      {Registry, keys: :unique, name: Onslaught.SpawnerRegistry},
      Onslaught.SpawnerMessengeHandler,
      {DynamicSupervisor, name: Onslaught.SpawnerDynamicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
