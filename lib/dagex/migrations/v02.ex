defmodule Dagex.Migrations.V02 do
  @moduledoc false

  use Ecto.Migration

  @spec up(keyword()) :: nil
  def up(_opts \\ []) do
    execute("""
    CREATE OR REPLACE FUNCTION dagex_add_initial_path()
    RETURNS TRIGGER AS
    $$
    BEGIN
    IF (TG_OP = 'INSERT') THEN
      INSERT INTO dagex_paths (node_id, path) VALUES(NEW.id, text2ltree(NEW.id::text));
      IF (NEW.ext_id::text != '*') THEN
        PERFORM dagex_create_edge(NEW.node_type, '*', NEW.ext_id::text);
      END IF;
    END IF;
    RETURN NULL;
    END;
    $$
    LANGUAGE plpgsql;
    """)

    nil
  end

  @spec down(keyword()) :: nil
  def down(_opts \\ []) do
    execute("""
    CREATE OR REPLACE FUNCTION dagex_add_initial_path()
    RETURNS TRIGGER AS
    $$
    BEGIN
    IF (TG_OP = 'INSERT') THEN
      INSERT INTO dagex_paths (node_id, path) VALUES(NEW.id, text2ltree(NEW.id::text));
    END IF;
    RETURN NULL;
    END;
    $$
    LANGUAGE plpgsql;
    """)

    nil
  end
end
