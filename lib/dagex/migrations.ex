# The code in this file was initially taken from the Oban codebase
# (https://github.com/sorentwo/oban/blob/v2.10.1/lib/oban/migrations.ex) and is
# subject to the following copyright and licensing terms, which may differ from
# the remainder of this project:
# Copyright 2019 Parker Selbert
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Dagex.Migrations do
  @moduledoc """
  Migrations create and modify the database tables Dagex needs to function.

  ## Usage

  To use migrations in your application you'll need to generate an `Ecto.Migration` that wraps
  calls to `Dagex.Migrations`:

  ```bash
  mix ecto.gen.migration add_dagex
  ```

  Open the generated migration in your editor and call the `up` and `down` functions on
  `Dagex.Migrations`:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddDagex do
    use Ecto.Migration

    def up, do: Dagex.Migrations.up()

    def down, do: Dagex.Migrations.down()
  end
  ```

  This will run all of Dagex's versioned migrations for your database. Migrations between versions
  are idempotent. As new versions are released you may need to run additional migrations.

  Now, run the migration to create the table:

  ```bash
  mix ecto.migrate
  ```
  """

  use Ecto.Migration

  @initial_version 1
  @current_version 2

  @spec up(opts :: keyword()) :: :ok
  @doc """
  Run the `up` changes for all migrations between the initial version and the current version.

  ## Example

  Run all migrations up to the current version:

      Dagex.Migrations.up()

  Run migrations up to a specified version:

      Dagex.Migrations.up(version: 2)
  """
  def up(opts \\ []) when is_list(opts) do
    version = Keyword.get(opts, :version, @current_version)
    initial = migrated_version(repo())

    cond do
      initial == 0 ->
        change(@initial_version..version, :up)

      initial < version ->
        change((initial + 1)..version, :up)

      true ->
        :ok
    end

    Ecto.Migration.flush()
    :ok
  end

  @spec down(opts :: keyword()) :: :ok
  @doc """
  Run the `down` changes for all migrations between the current version and the initial version.

  ## Example

  Run all migrations from current version down to the first:

      Dagex.Migrations.down()

  Run migrations down to a specified version:

      Dagex.Migrations.down(version: 5)
  """
  def down(opts \\ []) when is_list(opts) do
    version = Keyword.get(opts, :version, @initial_version)
    initial = max(migrated_version(repo()), @initial_version)

    if initial >= version do
      change(initial..version, :down)
    end

    Ecto.Migration.flush()
    :ok
  end

  @spec initial_version() :: integer()
  @doc false
  def initial_version, do: @initial_version

  @spec current_version() :: integer()
  @doc false
  def current_version, do: @current_version

  @spec migrated_version(repo :: Ecto.Repo.t()) :: integer()
  @doc false
  def migrated_version(repo) do
    query = """
    SELECT description
    FROM pg_class
    LEFT JOIN pg_description ON pg_description.objoid = pg_class.oid
    LEFT JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
    WHERE pg_class.relname = 'dagex_nodes'
    """

    case repo.query(query) do
      {:ok, %{rows: [[version]]}} when is_binary(version) -> String.to_integer(version)
      _result -> 0
    end
  end

  @spec setup_node_type(String.t(), String.t()) :: Macro.t()
  defmacro setup_node_type(table_name, "1.0.0") do
    quote bind_quoted: [table_name: table_name] do
      execute(
        """
        CREATE OR REPLACE FUNCTION dagex_maintain_nodes_#{table_name}()
        RETURNS TRIGGER AS
        $$
        BEGIN
        IF (TG_OP = 'INSERT') THEN
          INSERT INTO dagex_nodes (node_type, ext_id) VALUES('#{table_name}', NEW.id::text);
        ELSIF (TG_OP = 'DELETE') THEN
          DELETE FROM dagex_nodes WHERE ext_id = OLD.id::text;
        END IF;
        RETURN NULL;
        END;
        $$
        LANGUAGE plpgsql;
        """,
        """
        DROP FUNCTION dagex_maintain_nodes_#{table_name}();
        """
      )

      execute(
        """
        CREATE OR REPLACE TRIGGER dagex_maintain_nodes_trigger_#{table_name}
        AFTER INSERT OR DELETE ON #{table_name}
        FOR EACH ROW EXECUTE FUNCTION dagex_maintain_nodes_#{table_name}();
        """,
        """
        DROP TRIGGER dagex_maintain_nodes_trigger_#{table_name} ON #{table_name};
        """
      )
    end
  end

  defmacro setup_node_type(table_name, "2.0.0") do
    quote bind_quoted: [table_name: table_name] do
      execute(
        """
        CREATE OR REPLACE FUNCTION dagex_maintain_nodes_#{table_name}()
        RETURNS TRIGGER AS
        $$
        BEGIN
        IF (TG_OP = 'INSERT') THEN
          IF (NEW.id::text = '*') THEN
            raise exception 'Cannot create node with id *; that id is reserved for the collection supremum' USING ERRCODE = 'check_violation', CONSTRAINT = 'dagex_reserved_supremum_id';
          END IF;
          INSERT INTO dagex_nodes (node_type, ext_id) VALUES('#{table_name}', '*') ON CONFLICT DO NOTHING;
          INSERT INTO dagex_nodes (node_type, ext_id) VALUES('#{table_name}', NEW.id::text);
        ELSIF (TG_OP = 'UPDATE') THEN
          IF (NEW.id != OLD.id) THEN
            UPDATE dagex_nodes SET ext_id = NEW.id::text WHERE ext_id = OLD.id::text;
          END IF;
        ELSIF (TG_OP = 'DELETE') THEN
          DELETE FROM dagex_nodes WHERE ext_id = OLD.id::text;
        END IF;
        RETURN NULL;
        END;
        $$
        LANGUAGE plpgsql;
        """,
        """
        DROP FUNCTION dagex_maintain_nodes_#{table_name}();
        """
      )

      execute(
        """
        CREATE OR REPLACE TRIGGER dagex_maintain_nodes_trigger_#{table_name}
        AFTER INSERT OR UPDATE OR DELETE ON #{table_name}
        FOR EACH ROW EXECUTE FUNCTION dagex_maintain_nodes_#{table_name}();
        """,
        """
        DROP TRIGGER dagex_maintain_nodes_trigger_#{table_name} ON #{table_name};
        """
      )
    end
  end

  defp change(range, direction, opts \\ []) do
    for index <- range do
      pad_idx = String.pad_leading(to_string(index), 2, "0")

      [__MODULE__, "V#{pad_idx}"]
      |> Module.concat()
      |> apply(direction, [opts])
    end

    case direction do
      :up -> record_version(opts, Enum.max(range))
      :down -> record_version(opts, Enum.min(range) - 1)
    end
  end

  defp record_version(_opts, 0), do: :ok

  defp record_version(_opts, version) do
    execute("COMMENT ON TABLE dagex_nodes IS '#{version}'")
  end
end
