defmodule Dagex.Migrations.V04 do
  @moduledoc false

  use Ecto.Migration

  @spec up(keyword()) :: nil
  def up(_opts \\ []) do
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
        raise exception USING MESSAGE = 'Cannot create edge: the parent node ' || parent_id || ' does not exist', ERRCODE = 'check_violation', CONSTRAINT = 'dagex_parent_exists_constraint';
      END IF;

      SELECT max(id) INTO child_node_id FROM dagex_nodes n WHERE n.node_type = nt AND n.ext_id = child_id;
      IF (child_node_id IS NULL) THEN
        raise exception USING MESSAGE = 'Cannot create edge: the child node ' || child_id || ' does not exist', ERRCODE = 'check_violation', CONSTRAINT = 'dagex_child_exists_constraint';
      END IF;

      PERFORM dagex_create_edge(parent_node_id, child_node_id);
    END;
    $$
    LANGUAGE plpgsql;
    """)

    nil
  end

  @spec down(keyword()) :: nil
  def down(_opts \\ []) do
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

    nil
  end
end
