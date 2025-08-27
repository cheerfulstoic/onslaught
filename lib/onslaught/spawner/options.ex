defmodule Onslaught.Spawner.Options do
  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed

  @session_mods [
    Onslaught.Session.GET
  ]

  defmodule Header do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :key, :string, default: ""
      field :value, :string, default: ""
    end

    def changeset(source, data) do
      source
      |> cast(data, ~w[key value]a)
      |> validate_required(~w[key value]a)
      |> Map.put(:action, :insert)
    end
  end

  defmodule SessionOptions do
    use Ecto.ParameterizedType

    def type(_session_mod), do: :map

    def init(session_mod) do
      options_mod = Module.concat(session_mod, Options)

      %{session_mod: session_mod, options_mod: options_mod}
    end

    def cast(data, %{options_mod: options_mod}) do
      struct(options_mod)
      |> options_mod.changeset(data)
      |> Ecto.Changeset.apply_action(:insert)
      |> case do
        {:ok, data} ->
          {:ok, data}

        {:error, changeset} ->
          {:error, changeset.errors}
      end
    end

    def load(data, _loader, params) do
      {:ok, data}
    end

    def dump(data, dumper, params) do
      {:ok, data}
    end

    def equal?(a, b, _params) do
      a == b
    end
  end

  @primary_key false
  embedded_schema do
    field :session_mod, Ecto.Enum, values: @session_mods
    field :delay_between_spawns_ms, :integer
    field :session_count, :integer
    field :seconds, :integer
    field :pool_count, :integer
    field :pool_size, :integer

    polymorphic_embeds_one(:session,
      types: [
        {Onslaught.Session.GET, Onslaught.Session.GET.Options}
      ],
      on_type_not_found: :raise,
      # ,
      on_replace: :update
    )

    # type_field_name: :session_mod,
    # use_parent_field_for_type: :session_mod
  end

  def new_changeset(data) do
    changeset(%Onslaught.Spawner.Options{}, data)
    |> Map.put(:action, :insert)
  end

  def changeset(source, data) do
    source
    |> cast(
      data,
      ~w[session_mod delay_between_spawns_ms session_count seconds pool_count pool_size]a
    )
    |> validate_required(
      ~w[session_mod delay_between_spawns_ms session_count seconds pool_count pool_size]a
    )
    |> validate_number(:delay_between_spawns_ms, greater_than_or_equal_to: 0)
    |> validate_number(:session_count, greater_than_or_equal_to: 1)
    |> validate_number(:seconds, greater_than_or_equal_to: 1)
    |> validate_number(:pool_count, greater_than_or_equal_to: 1)
    |> validate_number(:pool_size, greater_than_or_equal_to: 1)
    |> cast_polymorphic_embed(:session, required: true)
  end

  def validate_url(changeset, field, opts \\ []) do
    validate_change(changeset, field, fn _, value ->
      case URI.parse(value) do
        %URI{scheme: nil} ->
          "is missing a scheme (e.g. https)"

        %URI{host: nil} ->
          "is missing a host"

        %URI{host: host} ->
          case :inet.gethostbyname(Kernel.to_charlist(host)) do
            {:ok, _} -> nil
            {:error, _} -> "invalid host"
          end
      end
      |> case do
        error when is_binary(error) -> [{field, Keyword.get(opts, :message, error)}]
        _ -> []
      end
    end)
  end
end
