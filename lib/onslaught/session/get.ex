defmodule Onslaught.Session.GET do
  @behaviour Onslaught.Session.Adapter

  defmodule Options do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :url, :string, default: "https://hostname.com/path/to/something"

      embeds_many :base_headers, Onslaught.Spawner.Options.Header
    end

    def changeset(%Onslaught.Session.GET.Options{} = source, data) do
      source
      |> cast(data, [:url])
      |> validate_required([:url])
      |> Onslaught.Spawner.Options.validate_url(:url)
      |> cast_embed(:base_headers)
    end
  end

  def description do
    "Session which makes one request every second"
  end

  def ticks(opts) do
    [
      run: :timer.seconds(1)
    ]
  end

  def pool_status_url(opts), do: opts.session.url

  def tesla_middleware(opts) do
    base_headers = Enum.map(opts.base_headers, &{&1.key, &1.value})

    [
      {Tesla.Middleware.Headers, base_headers},
      {Tesla.Middleware.Retry, delay: 500, max_retries: 10, max_delay: 4_000}
    ]
  end

  def init(client, opts) do
    {:ok,
     %{
       opts: opts
     }}
  end

  def metric_tags(%{opts: opts}) do
    %{}
  end

  def handle_tick(:run, client, %{opts: opts}) do
    case Tesla.get(client, opts.url) do
      {:ok, result} ->
        %{error: false, status: result.status}

      other ->
        dbg(other)
    end
  end
end
