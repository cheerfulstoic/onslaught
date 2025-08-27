defmodule Onslaught.Spawner.Metrics do
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def record_request(spawner_uuid, http_status, duration) do
    GenServer.cast(__MODULE__, {:record_request, spawner_uuid, http_status, duration})
  end

  # Callbacks

  @impl true
  def init(_) do
    Process.send_after(self(), :tick, 1_000)

    {:ok, %{}}
  end

  def handle_cast({:record_request, spawner_uuid, http_status, duration}, grouped_durations) do
    duration = duration / 1_000_000_000

    grouped_durations = Map.update(grouped_durations, {spawner_uuid, calculate_timeslice(), http_status}, [duration], & [duration | &1])

    {:noreply, grouped_durations}
  end

  def handle_info(:tick, grouped_durations) do
    grouped_durations =
      Enum.filter(grouped_durations, fn {{spawner_uuid, timeslice, http_status}, durations} ->
        if timeslice == calculate_timeslice() do
          true
        else
          timeslice_datetime = DateTime.from_unix!(timeslice, :second)
          Phoenix.PubSub.broadcast(Onslaught.SpawnerPubSub, "metrics", {:metrics_summary, spawner_uuid, timeslice_datetime, http_status, summarize(durations)})

          false
        end
      end)
      |> Map.new()

    Process.send_after(self(), :tick, 1_000)

    {:noreply, grouped_durations}
  end

  defp calculate_timeslice do
    :os.system_time(:second)
  end

  def summarize(durations) do
    Statistex.statistics(durations)
      # |> Map.take(~w[average maximum median minimum]a)
      |> Map.take(~w[maximum median]a)
  end
end
