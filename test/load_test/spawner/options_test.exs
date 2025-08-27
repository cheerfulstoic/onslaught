defmodule Onslaught.Spawner.OptionsTest do
  use ExUnit.Case, async: true

  test "happy path" do
    changeset =
      Onslaught.Spawner.Options.new_changeset(%{
        "delay_between_spawns_ms" => 75,
        "pool_count" => 2,
        "pool_size" => 200,
        "session" => %{
          "url" => "https://www.google.com/",
          "base_headers" => [
            %{"key" => "content-type", "value" => "application/json"}
          ]
        },
        "session_count" => 2,
        "session_mod" => "Elixir.Onslaught.Session.Simple"
      })

    assert changeset.valid?
  end

  test "data of wrong type" do
    changeset =
      Onslaught.Spawner.Options.new_changeset(%{
        "delay_between_spawns_ms" => 75,
        "pool_count" => 2,
        "pool_size" => 200,
        "session" => %{
          "url" => "https://www.google.com/",
          "base_headers" => [
            %{"key" => "content-type", "value" => "application/json"}
          ]
        },
        "session_count" => "string!",
        "session_mod" => "Elixir.Onslaught.Session.Simple"
      })

    refute changeset.valid?
    assert changeset.errors == [
      {:session_count, {"is invalid", [type: :integer, validation: :cast]}}
    ]
  end

  test "nested data of wrong type" do
    changeset =
      Onslaught.Spawner.Options.new_changeset(%{
        "delay_between_spawns_ms" => 75,
        "pool_count" => 2,
        "pool_size" => 200,
        "session" => %{
          "url" => 1234,
          "base_headers" => [
            %{"key" => "content-type", "value" => "application/json"}
          ]
        },
        "session_count" => 2,
        "session_mod" => "Elixir.Onslaught.Session.Simple"
      })

    refute changeset.valid?

    assert changeset.changes.session.errors == [url: {"is invalid", [type: :string, validation: :cast]}]
  end
end

