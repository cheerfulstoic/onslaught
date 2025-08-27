defmodule Onslaught.Session do
  use GenServer

  defmodule Adapter do
    @callback description() :: String.t()
    # URL which can be passed to Finch to get pool status
    # Just needs to match scheme, host, and port of requests being made
    @callback ticks(keyword()) :: keyword()
    @callback pool_status_url(keyword()) :: String.t()
    @callback tesla_middleware(keyword()) :: [Tesla.Client.middleware()]
    @callback init(Tesla.Client.t(), keyword()) :: {:ok, term()} | {:error, term()}
    # Receives the state returned by a successful `init` call
    @callback metric_tags(any()) :: map()
    # Receives the Tesla client and the state returned by a successful `init` call
    @callback metric_tags(Tesla.Client.t(), any()) :: term()
    @callback handle_tick(atom(), Tesla.Client.t(), term()) :: term()
  end

  def start_link(arg) do
    # Task.start_link(__MODULE__, :run, [arg])
    GenServer.start_link(__MODULE__, arg)
  end

  @impl true
  def init({spawn_uuid, spawner_uuid}) do
    opts = opts(spawner_uuid)
    session_mod = opts.session_mod

    Phoenix.PubSub.broadcast(
      Onslaught.PubSub,
      "sessions",
      {:session_started, spawn_uuid, spawner_uuid, self()}
    )

    {:ok, {spawn_uuid, spawner_uuid}, {:continue, :init_session}}
  end

  def handle_continue(
        :init_session,
        {spawn_uuid, spawner_uuid} = state
      ) do
    opts = opts(spawner_uuid)
    client = client(spawner_uuid)

    session_mod = opts.session_mod

    for {name, interval} <- session_mod.ticks(opts) do
      total_ticks = round(Float.ceil(:timer.seconds(opts.seconds) / interval))

      Process.send_after(self(), {:tick, name, interval, total_ticks}, interval)
    end

    case session_mod.init(client, opts.session) do
      {:ok, session_state} ->
        {:noreply, {session_state, spawn_uuid, spawner_uuid, opts.session_mod}}

      {:error, reason} ->
        {:stop, reason, nil}
    end
  end

  def handle_info(
        {:tick, _, _, 0},
        {session_state, spawn_uuid, spawner_uuid, _} = state
      ) do
    # Check if the `Process.send_after`s have finished
    with {:messages, []} <- Process.info(self(), :messages) do
      Phoenix.PubSub.broadcast(
        Onslaught.PubSub,
        "sessions",
        {:session_finished, spawn_uuid, spawner_uuid, self()}
      )
    end

    {:noreply, state, :hibernate}
  end

  def handle_info(
        {:tick, name, interval, ticks_left},
        {session_state, spawn_uuid, spawner_uuid, session_mod} = state
      ) do
    client = client(spawner_uuid)

    # tags = session_mod.metric_tags(state)

    session_state = session_mod.handle_tick(name, client, session_state)

    Process.send_after(self(), {:tick, name, interval, ticks_left - 1}, interval)

    {:noreply, {session_state, spawn_uuid, spawner_uuid, session_mod}, :hibernate}
  end

  def pool_status_url(opts) do
    opts.session_mod.pool_status_url(opts)
  end

  def client(spawner_uuid) do
    ets_name = :"spawner_#{spawner_uuid}"

    with [{:client, client}] <- :ets.lookup(ets_name, :client) do
      client
    end
  end

  def opts(spawner_uuid) do
    ets_name = :"spawner_#{spawner_uuid}"

    with [{:opts, opts}] <- :ets.lookup(ets_name, :opts) do
      opts
    end
  end
end
