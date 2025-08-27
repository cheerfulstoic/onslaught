defmodule Onslaught.SpawnerMessengeHandler do
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  # Callbacks

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(Onslaught.SpawnerPubSub, "spawn")

    {:ok, nil}
  end

  def handle_info({:spawn, spawn_uuid, opts}, state) do
    Onslaught.Spawner.spawn(spawn_uuid, opts)

    {:noreply, state}
  end

  def handle_info({:stop_spawn, spawn_uuid}, state) do
    Registry.select(Onslaught.SpawnerRegistry, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.map(fn {_uuid, pid, {found_spawn_uuid, _opts}} ->
      if spawn_uuid == found_spawn_uuid do
        DynamicSupervisor.terminate_child(Onslaught.SpawnerDynamicSupervisor, pid)
      end
    end)

    {:noreply, state}
  end
end
