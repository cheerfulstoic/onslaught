defmodule OnslaughtWeb.ListSpawners do
  use OnslaughtWeb, :live_view

  alias OnslaughtWeb.SpawnerChartComponent

  def mount(params, _, socket) do
    # Process.flag(:trap_exit, true)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Onslaught.SpawnerPubSub, "spawners")
      Phoenix.PubSub.subscribe(Onslaught.SpawnerPubSub, "metrics")
      Phoenix.PubSub.subscribe(Onslaught.PubSub, "sessions")
    end

    send(self(), :update_spawners)

    {:ok,
     socket
     |> assign(:spawn_uuid, params["spawn_uuid"])
     |> assign(:spawners_by_spawn_uuid, Onslaught.Spawner.spawners_by_spawn_uuid())}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="max-w-6xl mx-auto px-4">
        <div class="flex items-center justify-between mb-6">
          <div>
            <%= if @spawn_uuid do %>
              <h1 class="text-2xl font-bold text-gray-900">Focused on spawn: {@spawn_uuid}</h1>
            <% else %>
              <h1 class="text-2xl font-bold text-gray-900">All Spawners</h1>
            <% end %>
          </div>

          <div class="flex items-center gap-3">
            <%= if @spawn_uuid do %>
              <.link
                href={~p"/"}
                class="inline-flex items-center px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white font-semibold rounded-lg shadow-md transition duration-200 ease-in-out"
              >
                Show All Spawners
              </.link>
            <% end %>

            <.link
              href={~p"/create_spawner"}
              class="inline-flex items-center px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-lg shadow-md transition duration-200 ease-in-out transform hover:scale-105"
            >
              Create New Spawner
            </.link>
          </div>
        </div>

        <div class="bg-green-50 border border-green-200 rounded-lg p-4 space-y-4 mb-2">
          <h1 class="text-2xl font-bold text-gray-900">
            {length(Node.list()) + 1} total nodes connected
          </h1>
        </div>

        <%= for {spawn_uuid, spawners} <- @spawners_by_spawn_uuid, is_nil(@spawn_uuid) or spawn_uuid == @spawn_uuid do %>
          <div class="bg-white shadow-sm rounded-lg p-6 mb-6">
            <h2 class="text-xl font-bold text-gray-800 mb-4">Spawn: {spawn_uuid}</h2>

            <.link
              phx-click="shutdown-spawn"
              phx-value-spawn-uuid={spawn_uuid}
              class="inline-flex items-center px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-lg shadow-md transition duration-200 ease-in-out transform hover:scale-105"
            >
              Stop
            </.link>

            <details class="mt-3 mb-3">
              <summary class="cursor-pointer text-sm text-indigo-600 hover:text-indigo-800">
                View Options
              </summary>
              <pre class="text-xs bg-gray-100 p-2 rounded mt-2 overflow-auto">{inspect(List.first(spawners).opts, pretty: true)}</pre>
            </details>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for spawner <- spawners do %>
                <div class="border border-gray-200 rounded-lg p-4 bg-gradient-to-br from-indigo-50 to-indigo-100">
                  <p class="font-semibold text-gray-700">
                    node: <span class="font-mono text-sm">{inspect(spawner.node)}</span>
                  </p>
                  <p class="font-semibold text-gray-700">
                    UUID: <span class="font-mono text-sm">{inspect(spawner.uuid)}</span>
                  </p>
                  <p class="text-gray-600 mt-2">
                    Sessions:
                    <span class="font-bold">
                      {spawner.session_count} / {spawner.opts.session_count}
                    </span>
                  </p>

                  <p>
                    Pool connections in-use:
                    <span class="font-bold">
                      {pool_connections_in_use_string(spawner.pool_status)}
                    </span>
                  </p>

                  <.live_component
                    module={SpawnerChartComponent}
                    id={"chart-#{spawner.uuid}"}
                    spawner_uuid={spawner.uuid}
                  />
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def pool_connections_in_use_string({:ok, statuses}) do
    Enum.map_join(statuses, " | ", fn %Finch.HTTP1.PoolMetrics{} = metrics ->
      "##{metrics.pool_index}: #{metrics.in_use_connections}/#{metrics.pool_size}"
    end)
  end

  def pool_connections_in_use_string({:error, :spawner_not_found}), do: "SPAWNER NOT FOUND"

  def pool_connections_in_use_string({:error, :not_found}), do: "POOL NOT FOUND"

  def handle_event("shutdown-spawn", %{"spawn-uuid" => spawn_uuid}, socket) do
    :ok = Onslaught.Spawner.stop_spawn(spawn_uuid)

    Process.sleep(500)

    {:noreply,
     socket
     |> assign(:spawners_by_spawn_uuid, Onslaught.Spawner.spawners_by_spawn_uuid())}
  end

  def handle_info({:spawner_started, spawn_uuid, node, uuid}, socket) do
    {:noreply,
     socket
     |> update(:spawners_by_spawn_uuid, fn spawners_by_spawn_uuid ->
       spawner = Onslaught.Spawner.spawner(node, uuid)

       Map.update(spawners_by_spawn_uuid, spawn_uuid, [spawner], &[spawner | &1])
     end)}
  end

  def handle_info({:session_started, spawn_uuid, spawner_uuid, _pid}, socket) do
    # {:noreply, update_spawner(socket, spawn_uuid, spawner_uuid)}
    {:noreply, socket}
  end

  def handle_info({:session_finished, spawn_uuid, spawner_uuid, _pid}, socket) do
    # {:noreply, update_spawner(socket, spawn_uuid, spawner_uuid)}
    {:noreply, socket}
  end

  def handle_info(:update_spawners, socket) do
    Process.send_after(self(), :update_spawners, 500)

    {:noreply, update_spawners(socket)}
  end

  def handle_info({:metrics_summary, spawner_uuid, timeslice, http_status, statistics}, socket) do
    send_update(SpawnerChartComponent,
      id: "chart-#{spawner_uuid}",
      spawner_uuid: spawner_uuid,
      timeslice: timeslice,
      http_status: http_status,
      statistics: statistics
    )

    {:noreply, socket}
  end

  def update_spawners(socket) do
    socket
    |> update(:spawners_by_spawn_uuid, fn spawners_by_spawn_uuid ->
      Map.new(spawners_by_spawn_uuid, fn {spawn_uuid, spawners} ->
        {
          spawn_uuid,
          Enum.map(spawners, fn spawner ->
            Onslaught.Spawner.spawner(spawner.node, spawner.uuid)
          end)
        }
      end)
    end)
  end

  def update_spawner(socket, _spawn_uuid, spawner_uuid) do
    socket
    |> update(:spawners_by_spawn_uuid, fn spawners_by_spawn_uuid ->
      Map.new(spawners_by_spawn_uuid, fn {spawn_uuid, spawners} ->
        spawners =
          Enum.map(spawners, fn spawner ->
            if spawner.uuid == spawner_uuid do
              Onslaught.Spawner.spawner(spawner.node, spawner_uuid)
            else
              spawner
            end
          end)

        {spawn_uuid, spawners}
      end)
    end)
  end

  # def update_pool_statuses(socket) do
  #   update(socket, :spawners_by_spawn_uuid, fn spawners_by_spawn_uuid ->
  #     Map.new(spawners_by_spawn_uuid, fn {spawn_uuid, spawners} ->
  #       {
  #         spawn_uuid,
  #         Enum.map(spawners, fn spawner ->
  #           Map.put(
  #             spawner,
  #             :pool_status,
  #             Onslaught.Spawner.pool_status(spawner.node, spawner.uuid)
  #           )
  #         end)
  #       }
  #     end)
  #   end)
  # end
  #
end
