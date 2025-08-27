defmodule Onslaught.Spawner do
  use Supervisor

  alias Onslaught.Spawner.Metrics

  require Logger

  def broadcast_spawn(opts) do
    spawn_uuid = Ecto.UUID.generate()

    with :ok <-
           Phoenix.PubSub.broadcast(Onslaught.SpawnerPubSub, "spawn", {:spawn, spawn_uuid, opts}) do
      {:ok, spawn_uuid}
    end
  end

  def spawn(spawn_uuid, opts) do
    uuid = Ecto.UUID.generate()

    DynamicSupervisor.start_child(
      Onslaught.SpawnerDynamicSupervisor,
      {__MODULE__, {spawn_uuid, uuid, opts}}
    )

    {:ok, uuid}
  end

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @impl true
  def init({spawn_uuid, uuid, opts}) do
    finch_name = finch_name(uuid)

    # TODO: Put this under a process
    ets_name = :"spawner_#{uuid}"
    :ets.new(ets_name, [:set, :protected, :named_table, read_concurrency: true])

    client =
      Tesla.client(
        opts.session_mod.tesla_middleware(opts.session) ++
          [
            {Tesla.Middleware.Headers, [{"User-Agent", "onslaught/0.1.0"}]},
            Tesla.Middleware.Telemetry
          ],
        {Tesla.Adapter.Finch, name: finch_name}
      )

    :ets.insert(ets_name, {:client, client})
    :ets.insert(ets_name, {:opts, opts})

    children = [
      {Finch,
       name: finch_name,
       pools: %{
         default: [
           count: opts.pool_count,
           size: opts.pool_size,
           start_pool_metrics?: true,
           conn_opts: [
             transport_opts: [
               # session_cache_server_max: 100
               # session_cache_client_max: 100

               # Disable session tickets if not needed
               # session_tickets: :disabled,

               # Reduce buffer sizes
               # buffer: 16384,
               # ciphers: :ssl.cipher_suites(:default, :"tlsv1.2")
             ]
           ]
         ]
       }},
      %{
        id: task_name(uuid),
        start: {Task, :start_link, [fn -> Onslaught.Spawner.task({spawn_uuid, uuid, opts}) end]},
        restart: :transient
      },
      {DynamicSupervisor, name: dynamic_supervisor_name(uuid), strategy: :one_for_one},
      {Task,
       fn ->
         Phoenix.PubSub.broadcast(
           Onslaught.SpawnerPubSub,
           "spawners",
           {:spawner_started, spawn_uuid, Node.self(), uuid}
         )
       end}
    ]

    Registry.register(Onslaught.SpawnerRegistry, uuid, {spawn_uuid, opts})

    Supervisor.init(children, strategy: :rest_for_one)
  end

  def task({spawn_uuid, uuid, opts}) do
    Process.sleep(500)

    event = [:tesla, :request, :stop]
    id = {__MODULE__, event, self()}

    :telemetry.attach(
      id,
      event,
      &__MODULE__.handle_event/4,
      %{spawn_uuid: spawn_uuid, spawner_uuid: uuid}
    )

    for i <- 1..opts.session_count do
      {:ok, pid} =
        DynamicSupervisor.start_child(
          dynamic_supervisor_name(uuid),
          {Onslaught.Session, {spawn_uuid, uuid}}
        )

      Process.sleep(opts.delay_between_spawns_ms)
    end
  end

  def handle_event([:tesla, :request, :stop], %{duration: duration}, metadata, config) do
    # IO.puts("HANDLE_EVENT")
    Metrics.record_request(config.spawner_uuid, metadata.env.status, duration)

    config
  end

  # def spawners_by_node do
  #   [Node.self() | Node.list()]
  #   |> Enum.map(fn node ->
  #     case maybe_run_on_node(node, __MODULE__, :spawners, []) do
  #       {:badrpc, error} ->
  #         Logger.error("BAD RPC: #{inspect(error)}")
  #         nil
  #
  #       spawners ->
  #         {node, spawners}
  #     end
  #   end)
  #   |> Enum.reject(&is_nil/1)
  #   |> Map.new()
  # end

  def spawners_by_spawn_uuid do
    [Node.self() | Node.list()]
    |> Enum.flat_map(fn node ->
      case maybe_run_on_node(node, __MODULE__, :spawners, []) do
        {:badrpc, error} ->
          Logger.error("BAD RPC: #{inspect(error)}")
          nil

        spawners ->
          spawners
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(& &1.spawn_uuid)
  end

  def spawners do
    Registry.select(Onslaught.SpawnerRegistry, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.map(fn {uuid, pid, {spawn_uuid, opts}} ->
      %{
        spawn_uuid: spawn_uuid,
        uuid: uuid,
        session_count: count_sessions(uuid),
        opts: opts,
        node: Node.self(),
        pool_status: {:ok, []}
      }
    end)
  end

  def spawner(node, uuid) do
    maybe_run_on_node(node, __MODULE__, :spawner, [uuid])
  end

  def pool_status(node, uuid) do
    maybe_run_on_node(node, __MODULE__, :pool_status, [uuid])
  end

  def stop_spawn(spawn_uuid) do
    Phoenix.PubSub.broadcast(Onslaught.SpawnerPubSub, "spawn", {:stop_spawn, spawn_uuid})
  end

  # def stop(uuid) do
  #   Registry.lookup(Onslaught.SpawnerRegistry, uuid)
  #   |> case do
  #     [{pid, {_spawn_uuid, _opts}}] ->
  #       DynamicSupervisor.terminate_child(Onslaught.SpawnerDynamicSupervisor, pid)
  #
  #     [] ->
  #       raise "Spawner not found: #{uuid}"
  #   end
  # end

  def spawner(uuid) do
    Registry.lookup(Onslaught.SpawnerRegistry, uuid)
    |> case do
      [{_pid, {spawn_uuid, opts}}] ->
        %{
          spawn_uuid: spawn_uuid,
          uuid: uuid,
          session_count: count_sessions(uuid),
          opts: opts,
          node: Node.self(),
          pool_status: pool_status(uuid)
        }

      [] ->
        raise "Spawner not found: #{uuid}"
    end
  end

  def pool_status(uuid) do
    Registry.lookup(Onslaught.SpawnerRegistry, uuid)
    |> case do
      [{_pid, {_spawn_uuid, opts}}] ->
        Finch.get_pool_status(
          finch_name(uuid),
          Onslaught.Session.pool_status_url(opts)
        )

      [] ->
        {:ok, :spawner_not_found}
    end
  end

  def count_sessions(uuid) do
    dynamic_supervisor_name = dynamic_supervisor_name(uuid)

    %{active: active} = DynamicSupervisor.count_children(dynamic_supervisor_name)

    active
  end

  defp maybe_run_on_node(node, module, func, args) do
    if node == Node.self() do
      apply(module, func, args)
    else
      :rpc.call(node, module, func, args)
    end
  end

  def finch_name(uuid) do
    :"Finch-#{uuid}"
  end

  defp task_name(uuid) do
    :"SpawnerTask-#{uuid}"
  end

  defp dynamic_supervisor_name(uuid) do
    :"SpawnerDynamicSupervisor-#{uuid}"
  end

  defp run_on_node(nil, func), do: func.()
  defp run_on_node(node, func), do: Node.spawn_link(node, func)
end
