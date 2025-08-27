defmodule OnslaughtWeb.SpawnerChartComponent do
  use OnslaughtWeb, :live_component

  def mount(socket) do
    {:ok,
      socket
      |> assign(:chart, nil)
      |> assign(:data, %{})}
  end

  def update(assigns, socket) do
    if assigns[:timeslice] do
      {:ok,
        socket
        |> assign(:spawner_uuid, assigns.spawner_uuid)
        |> push_event("chart-js:new-data-#{assigns.spawner_uuid}", %{timeslice: assigns.timeslice, http_status: assigns.http_status, statistics: assigns.statistics})
        }
    else
      {:ok, assign(socket, :spawner_uuid, assigns.spawner_uuid)}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <canvas phx-hook="ChartJS" id={"chart-js-spawner-#{@spawner_uuid}"} data-spawner-uuid={@spawner_uuid} />
    </div>
    """
  end
end

