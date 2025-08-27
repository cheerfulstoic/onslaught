defmodule OnslaughtWeb.CreateSpawner do
  alias Onslaught.Spawner

  use OnslaughtWeb, :live_view

  @session_mods [
    Onslaught.Session.GET
  ]

  def mount(_, _, socket) do
    {:ok,
     socket
     |> assign_options(%{
       "delay_between_spawns_ms" => 75,
       "session_count" => 2,
       "seconds" => 60,
       "pool_count" => 1,
       "pool_size" => 200,
       "session_mod" => to_string(Onslaught.Session.GET),
       "session" => %{}
     })}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="max-w-4xl mx-auto px-4">
        <div class="bg-green-50 border border-green-200 rounded-lg p-4 space-y-4 mb-2">
          <h1 class="text-2xl font-bold text-gray-900">
            {length(Node.list()) + 1} total nodes connected
          </h1>
        </div>

        <.form
          for={@form}
          phx-change="validate"
          phx-submit="run"
          id="options-form"
          class="bg-white shadow-lg rounded-lg p-6 space-y-6"
        >
          <!-- Spawner Options -->
          <div class="bg-green-50 border border-green-200 rounded-lg p-4 space-y-4">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">Spawner Options</h3>

            <p>
              When you click the "Run!" button below, a "spawner" will be started on each server where onslaught is running. Spawners are in charge of starting up, over a period of time, the number of sessions which you specify.
            </p>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4">
              <div class="flex items-center">
                <label class="block text-sm font-medium text-gray-700 w-48 pr-4">
                  Delay between spawns (ms):
                </label>
                <div class="flex-1">
                  <.input type="number" field={@form[:delay_between_spawns_ms]} class="w-full" />
                </div>
              </div>

              <div class="flex items-center">
                <label class="block text-sm font-medium text-gray-700 w-48 pr-4">
                  Concurrent Sessions:
                </label>
                <div class="flex-1">
                  <.input type="number" field={@form[:session_count]} class="w-full" />
                </div>
              </div>
            </div>
          </div>
          
    <!-- Session Options -->
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 space-y-4">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">Session Options</h3>

            <p>
              Each session will loop the number of times you specify. For example, a "GET" session will just make a request once every one second, so starting up 100 sessions will create 100 requests/second of traffic.
            </p>

            <div class="flex items-center">
              <label class="block text-sm font-medium text-gray-700 w-48 pr-4">
                Number of seconds:
              </label>
              <div class="flex-1">
                <.input type="number" field={@form[:seconds]} class="w-full" />
              </div>
            </div>

            <div class="border-t border-blue-300 pt-4 mt-4">
              <div class="flex items-center gap-4 mb-4">
                <label class="block text-sm font-medium text-gray-700 w-48 flex-shrink-0">
                  Session type:
                </label>
                <div class="w-64 flex-shrink-0">
                  <.input
                    type="select"
                    field={@form[:session_mod]}
                    options={Enum.map(session_mods(), &{adapter_name(&1), to_string(&1)})}
                    class="w-full"
                  />
                </div>
                <div class="flex-1 text-sm text-gray-600">
                  <strong>{adapter_name(@form[:session_mod].value)}</strong>: {@form[:session_mod].value.description()}
                </div>
              </div>

              <.session_options form={@form} />
            </div>
          </div>
          
    <!-- HTTP Client Options -->
          <div class="bg-purple-50 border border-purple-200 rounded-lg p-4 space-y-4">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">HTTP Client Options</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4">
              <div class="flex items-center">
                <label class="block text-sm font-medium text-gray-700 w-48 pr-4">
                  Pool count:
                </label>
                <div class="flex-1">
                  <.input type="number" field={@form[:pool_count]} class="w-full" />
                </div>
              </div>

              <div class="flex items-center">
                <label class="block text-sm font-medium text-gray-700 w-48 pr-4">
                  Pool size:
                </label>
                <div class="flex-1">
                  <.input type="number" field={@form[:pool_size]} class="w-full" />
                </div>
              </div>
            </div>
          </div>

          <div class="flex justify-end pt-4">
            <.button
              type="submit"
              class="bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2 px-6 rounded-lg shadow-md transition duration-200 ease-in-out transform hover:scale-105"
            >
              Run Load Test!
            </.button>
          </div>
        </.form>
      </div>

      <script>
        // Not the ideal approach, but I tried a bunch of others...
        function addHeader(key) {
          let parent = document.getElementById(`${key}-headers-fields`)

          let index = parent.getElementsByClassName('header-group').length

          let newHTML = `
            <input
              type="hidden"
              name="options[session][base_headers][${index}][_persistent_id]"
              value="${index}"
            />

            <div class="flex items-center gap-2 header-group bg-white p-2 rounded border">
              <div class="flex-1">
                <input type="text" name="options[session][${key}][${index}][key]" id="options_session_0_${key}_${index}_key" value="" class="w-full input" placeholder="Header key">
              </div>
              <div class="flex-1">
                <input type="text" name="options[session][${key}][${index}][value]" id="options_session_0_${key}_${index}_value" value="" class="w-full input" placeholder="Header value">
              </div>
            </div>
          `

          parent.insertAdjacentHTML('beforeend', newHTML);

          document.getElementById('options-form').dispatchEvent(new Event('input', { bubbles: true }));
        }
      </script>
    </div>
    """
  end

  def adapter_name(module) do
    module
    |> Module.split()
    |> List.last()
  end

  def session_options(assigns) do
    ~H"""
    <.polymorphic_embed_inputs_for :let={session_form} field={@form[:session]}>
      <% options_schema = source_module(session_form) %>

      <div class="space-y-4 mt-4">
        <%= for key <- options_schema.__schema__(:fields), type = options_schema.__schema__(:type, key) do %>
          <.session_option field={session_form[key]} key={key} type={type} />
        <% end %>
      </div>
    </.polymorphic_embed_inputs_for>
    """
  end

  def session_option(%{type: :string} = assigns) do
    ~H"""
    <div class="flex items-center">
      <label class="block text-sm font-medium text-gray-700 w-32 pr-4 capitalize">
        {@key}:
      </label>
      <div class="flex-1">
        <.input field={@field} class="w-full" />
      </div>
    </div>
    """
  end

  def session_option(
        %{
          type:
            {:parameterized,
             {Ecto.Embedded,
              %Ecto.Embedded{cardinality: :many, related: Onslaught.Spawner.Options.Header}}}
        } = assigns
      ) do
    ~H"""
    <div class="space-y-3">
      <label class="block text-sm font-medium text-gray-700 capitalize">
        {@key}:
      </label>

      <div id={"#{@key}-headers-fields"} class="space-y-2">
        <.inputs_for :let={form} field={@field}>
          <div class="flex items-center gap-2 header-group bg-white p-2 rounded border">
            <div class="flex-1">
              <.input field={form[:key]} placeholder="Header key" class="w-full" />
            </div>
            <div class="flex-1">
              <.input field={form[:value]} placeholder="Header value" class="w-full" />
            </div>
          </div>
        </.inputs_for>
      </div>
      <.button
        type="button"
        onclick={"javascript:addHeader('#{@key}')"}
        phx-value-key={@key}
        class="bg-green-600 hover:bg-green-700 text-white text-sm px-3 py-1 rounded"
      >
        Add Header
      </.button>
    </div>
    """
  end

  def session_option(assigns) do
    ~H"""
    <div>
      <p>NOT SUPPORTED OPTION!! FIX THIS! GOT:</p>

      <p>key: {@key}</p>
      <p>type: <pre>{inspect(@type)}</pre></p>
    </div>
    """
  end

  def handle_event("validate", %{"options" => options}, socket) do
    {:noreply, assign_options(socket, options)}
  end

  def handle_event("run", %{"options" => options}, socket) do
    options
    |> Spawner.Options.new_changeset()
    |> Ecto.Changeset.apply_action(:insert)
    |> case do
      {:ok, options} ->
        {:ok, spawn_uuid} = Onslaught.Spawner.broadcast_spawn(options)

        IO.puts("SPAWNED #{spawn_uuid}!")

        {:noreply, push_redirect(socket, to: ~p"/spawners/#{spawn_uuid}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Form had errors!")}
    end
  end

  defp assign_options(socket, options) do
    session_mod = Enum.find(@session_mods, &(to_string(&1) == options["session_mod"]))

    options = put_in(options, ["session", "__type__"], to_string(session_mod))

    changeset = Spawner.Options.new_changeset(options)

    socket
    |> assign(:form, to_form(changeset))
    |> assign(:session_mod, session_mod)
  end

  defp session_mods, do: @session_mods
end
