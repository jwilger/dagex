defmodule Dagex.Migrations.V01 do
  @moduledoc false

  use Ecto.Migration

  @spec up(keyword()) :: nil
  def up(_opts \\ []) do
    execute("CREATE EXTENSION IF NOT EXISTS ltree", "")

    create table("dagex_nodes") do
      add(:node_type, :string, null: false)
      add(:ext_id, :string, null: false)
    end

    create(index("dagex_nodes", [:ext_id, :node_type], unique: true))

    create table("dagex_paths") do
      add(:node_id, references("dagex_nodes", validate: true, on_delete: :delete_all), null: false)

      add(:path, :ltree, null: false)
    end

    execute(
      "ALTER TABLE dagex_paths ADD CONSTRAINT dagex_paths_unique UNIQUE(path) DEFERRABLE INITIALLY IMMEDIATE"
    )

    execute("CREATE INDEX dagex_paths_gist ON dagex_paths USING gist(path)")

    execute("CREATE INDEX dagex_paths_btree ON dagex_paths USING btree(path)")

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

    execute("""
    CREATE TRIGGER dagex_add_initial_path_trigger
    AFTER INSERT ON dagex_nodes
    FOR EACH ROW EXECUTE FUNCTION dagex_add_initial_path();
    """)

    execute("""
    CREATE OR REPLACE FUNCTION dagex_create_edge(nt text, parent_id text, child_id text)
    RETURNS void AS
    $$
    DECLARE
      parent_node_id bigint;
      child_node_id bigint;
    BEGIN
      SELECT max(id) INTO parent_node_id FROM dagex_nodes n WHERE n.node_type = nt AND n.ext_id = parent_id;
      IF (parent_node_id IS NULL) THEN
        raise exception 'Cannot create edge: the parent node does not exist' USING ERRCODE = 'check_violation', CONSTRAINT = 'dagex_parent_exists_constraint';
      END IF;

      SELECT max(id) INTO child_node_id FROM dagex_nodes n WHERE n.node_type = nt AND n.ext_id = child_id;
      IF (child_node_id IS NULL) THEN
        raise exception 'Cannot create edge: the parent node does not exist' USING ERRCODE = 'check_violation', CONSTRAINT = 'dagex_child_exists_constraint';
      END IF;

      PERFORM dagex_create_edge(parent_node_id, child_node_id);
    END;
    $$
    LANGUAGE plpgsql;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION dagex_create_edge(parent_id bigint, child_id bigint)
    RETURNS void AS
    $$
    DECLARE
        parent text := CAST(parent_id as text);
        child  text := CAST(child_id as text);
    BEGIN
        if parent = child
        then
            raise exception 'Cannot create edge: the parent is the same as the child.' USING ERRCODE = 'check_violation', CONSTRAINT = 'dagex_edge_constraint';
        end if;

        if EXISTS(
                SELECT 1
                FROM dagex_paths
                where dagex_paths.path ~ CAST('*.' || child || '.*.' || parent || '.*' as lquery)
            )
        then
        raise exception 'Cannot create edge: child already contains parent.' USING ERRCODE = 'check_violation', CONSTRAINT = 'dagex_edge_constraint';
        end if;

        insert into dagex_paths (node_id, path) (
            select distinct node_id, fp.path || subpath(dagex_paths.path, index(dagex_paths.path, text2ltree(child)))
            from dagex_paths,
                (select dagex_paths.path from dagex_paths where dagex_paths.path ~ CAST('*.' || parent AS lquery)) as fp
            where dagex_paths.path ~ CAST('*.' || child || '.*' AS lquery)
        );
        delete from dagex_paths where dagex_paths.path ~ CAST(child || '.*' AS lquery);
    END
    $$
    LANGUAGE plpgsql;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION dagex_remove_edge(nt text, parent_id text, child_id text)
    RETURNS void AS
    $$
    DECLARE
      parent_node_id bigint;
      child_node_id bigint;
    BEGIN
      SELECT max(id) INTO parent_node_id FROM dagex_nodes n WHERE n.node_type = nt AND n.ext_id = parent_id;
      SELECT max(id) INTO child_node_id FROM dagex_nodes n WHERE n.node_type = nt AND n.ext_id = child_id;

      IF (parent_node_id IS NOT NULL AND child_node_id IS NOT NULL) THEN
        PERFORM dagex_remove_edge(parent_node_id, child_node_id);
      END IF;
    END;
    $$
    LANGUAGE plpgsql;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION dagex_remove_edge(parent_id bigint, child_id bigint)
    RETURNS void AS
    $$
    DECLARE
        parent text := CAST(parent_id as text);
        child  text := CAST(child_id as text);
        number int;
    BEGIN
        SET CONSTRAINTS dagex_paths_unique DEFERRED;
        UPDATE dagex_paths
          SET path = subpath(path, index(path, text2ltree(child)))
          WHERE path ~ CAST('*.' || parent || '.' || child || '.*' AS lquery);

        DELETE
          FROM dagex_paths
          WHERE id IN (SELECT id
                        FROM (SELECT id, ROW_NUMBER() OVER (partition BY node_id, path) AS rnum
                                FROM dagex_paths) t
                        WHERE t.rnum > 1);

        SET CONSTRAINTS dagex_paths_unique IMMEDIATE;

        select COUNT(1) into number from dagex_paths where node_id = child_id;
        IF number > 1
        THEN
            delete from dagex_paths where path <@ text2ltree(child);
        end if;

    END
    $$
    LANGUAGE plpgsql;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION dagex_delete_paths_for_node()
    RETURNS TRIGGER AS
    $$
    BEGIN
    IF (TG_OP = 'DELETE') THEN
      DELETE FROM dagex_paths WHERE path ~ CAST('*.' || OLD.id::text || '.*' AS lquery);
    END IF;
    RETURN NULL;
    END;
    $$
    LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER dagex_delete_paths_for_node_trigger
    AFTER DELETE ON dagex_nodes
    FOR EACH ROW EXECUTE FUNCTION dagex_delete_paths_for_node();
    """)

    nil
  end

  @spec down(keyword()) :: nil
  def down(_opts \\ []) do
    execute("DROP TRIGGER dagex_delete_paths_for_node_trigger ON dagex_nodes;")
    execute("DROP FUNCTION dagex_delete_paths_for_node();")
    execute("DROP FUNCTION dagex_remove_edge(parent_id bigint, child_id bigint);")
    execute("DROP FUNCTION dagex_remove_edge(node_type text, parent_id text, child_id text);")
    execute("DROP FUNCTION dagex_create_edge(parent_id bigint, child_id bigint);")
    execute("DROP FUNCTION dagex_create_edge(node_type text, parent_id text, child_id text);")
    execute("DROP TRIGGER dagex_add_initial_path_trigger ON dagex_nodes;")
    execute("DROP FUNCTION dagex_add_initial_path();")
    drop(table("dagex_paths"))
    drop(table("dagex_nodes"))
    nil
  end
end
