defmodule DagexTest do
  use ExUnit.Case, async: true
  require Assertions

  doctest Dagex

  alias DagexTest.{Repo, TypeA, TypeB}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "creating an entity adds a nodes record" do
    %{id: entity_id} = Repo.insert!(%TypeA{name: "bar"})
    entity_id = to_string(entity_id)

    {:ok, %{rows: [[^entity_id]]}} =
      Repo.query("SELECT ext_id FROM dagex_nodes WHERE ext_id = $1", [entity_id])
  end

  test "creating an entity adds an initial paths record" do
    %{id: entity_id} = Repo.insert!(%TypeA{name: "bar"})
    entity_id = to_string(entity_id)

    {:ok, %{rows: [[^entity_id]]}} =
      Repo.query(
        "SELECT n.ext_id FROM dagex_paths p JOIN dagex_nodes n ON p.node_id = n.id WHERE n.ext_id = $1 AND p.path = text2ltree(n.id::text)",
        [entity_id]
      )
  end

  test "deleting an entity removes its node record" do
    %{id: entity_id} = entity = Repo.insert!(%TypeA{name: "bar"})
    entity_id = to_string(entity_id)
    Repo.delete!(entity)

    {:ok, %{rows: []}} =
      Repo.query("SELECT ext_id FROM dagex_nodes WHERE ext_id = $1", [entity_id])
  end

  test "deleting an entity removes associated paths" do
    {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
    {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
    {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()
    {:ok, entity_d} = %TypeA{name: "d"} |> Repo.insert()

    {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
    {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_c) |> Repo.dagex_update()
    {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
    {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_d) |> Repo.dagex_update()

    Repo.delete!(entity_b)
    Repo.delete!(entity_c)

    assert [] == TypeA.descendants(entity_a) |> Repo.all()
    assert [] == TypeA.ancestors(entity_d) |> Repo.all()
  end

  describe "roots/0" do
    test "contains a list of entities that do not have any parents in the graph" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()
      roots = TypeA.roots() |> Repo.all()
      assert Enum.count(roots) == 2
      assert entity_a in roots
      assert entity_b in roots
    end

    test "does not contain entities of a different node_type" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeB{name: "baz"} |> Repo.insert()
      roots = TypeA.roots() |> Repo.all()
      assert Enum.count(roots) == 1
      assert entity_a in roots
      refute entity_b in roots
    end

    test "does not contain entities that have at least one parent node" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      roots = TypeA.roots() |> Repo.all()
      assert Enum.count(roots) == 1
      assert entity_a in roots
      refute entity_b in roots
    end
  end

  describe "create_edge/2" do
    test "returns {:ok, edge_tuple} if edge can be created" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()

      {:edge_created, {^entity_a, ^entity_b}} =
        TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
    end

    test "creating an edge is idempotent" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()

      {:edge_created, {^entity_a, ^entity_b}} =
        TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()

      {:edge_created, {^entity_a, ^entity_b}} =
        TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
    end

    test "returns {:error, :cyclic_edge} if parent and child are the same" do
      {:ok, entity} = %TypeA{name: "bar"} |> Repo.insert()
      {:error, :cyclic_edge} = TypeA.create_edge(entity, entity) |> Repo.dagex_update()
    end

    test "returns {:error, :cyclic_edge} if parent is a child of child" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()

      {:edge_created, _result} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:error, :cyclic_edge} = TypeA.create_edge(entity_b, entity_a) |> Repo.dagex_update()
    end

    test "returns {:error, :cyclic_edge} if child is an ancestor of parent" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "bam"} |> Repo.insert()

      {:edge_created, _result} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _result} = TypeA.create_edge(entity_b, entity_c) |> Repo.dagex_update()
      {:error, :cyclic_edge} = TypeA.create_edge(entity_c, entity_a) |> Repo.dagex_update()
    end

    test "returns {:error, :incompatible_nodes} if parent and child are not of same node_type" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeB{name: "baz"} |> Repo.insert()

      {:error, :incompatible_nodes} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:error, :incompatible_nodes} = TypeA.create_edge(entity_b, entity_a) |> Repo.dagex_update()
      {:error, :incompatible_nodes} = TypeB.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:error, :incompatible_nodes} = TypeB.create_edge(entity_b, entity_a) |> Repo.dagex_update()
    end

    test "returns {:error, :parent_not_found} if parent entity does not exist" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()
      Repo.delete!(entity_a)

      {:error, :parent_not_found} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
    end

    test "returns {:error, :child_not_found} if child entity does not exist" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()
      Repo.delete!(entity_b)

      {:error, :child_not_found} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
    end

    test "child nodes of the child become descendants of the parent" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()

      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_c) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()

      assert entity_c in (TypeA.descendants(entity_a) |> Repo.all())
    end

    test "parent nodes of the parent become ancestors of the child" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()

      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_c) |> Repo.dagex_update()

      assert entity_a in (TypeA.ancestors(entity_c) |> Repo.all())
    end
  end

  describe "remove_edge/2" do
    test "returns {:edge_removed, edge} if edge exists and has been removed" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()

      {:edge_removed, {^entity_a, ^entity_b}} =
        TypeA.remove_edge(entity_a, entity_b) |> Repo.dagex_update()
    end

    test "returns {:edge_removed, edge} if parent no longer exists" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      Repo.delete!(entity_a)

      {:edge_removed, {^entity_a, ^entity_b}} =
        TypeA.remove_edge(entity_a, entity_b) |> Repo.dagex_update()
    end

    test "returns {:edge_removed, edge} if child no longer exists" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      Repo.delete!(entity_b)

      {:edge_removed, {^entity_a, ^entity_b}} =
        TypeA.remove_edge(entity_a, entity_b) |> Repo.dagex_update()
    end

    test "returns {:edge_removed, edge} if edge doesn't already exist" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "baz"} |> Repo.insert()

      {:edge_removed, {^entity_a, ^entity_b}} =
        TypeA.remove_edge(entity_a, entity_b) |> Repo.dagex_update()
    end

    test "ancestors exclusively of parent are no longer ancestors of child" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()

      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_c) |> Repo.dagex_update()
      {:edge_removed, _edge} = TypeA.remove_edge(entity_b, entity_c) |> Repo.dagex_update()

      assert [] == TypeA.ancestors(entity_c) |> Repo.all()
    end

    test "ancestors from multiple paths remain ancestors of child" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()
      {:ok, entity_d} = %TypeA{name: "d"} |> Repo.insert()

      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_c) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_d) |> Repo.dagex_update()
      {:edge_removed, _edge} = TypeA.remove_edge(entity_b, entity_d) |> Repo.dagex_update()

      assert entity_a in (TypeA.ancestors(entity_d) |> Repo.all())
    end

    test "descendants exclusively of child are no longer descendants of parent" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()

      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_c) |> Repo.dagex_update()
      {:edge_removed, _edge} = TypeA.remove_edge(entity_a, entity_b) |> Repo.dagex_update()

      assert [] == TypeA.descendants(entity_a) |> Repo.all()
    end

    test "descendants from multiple paths remain descendants of parent" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()
      {:ok, entity_d} = %TypeA{name: "d"} |> Repo.insert()

      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_c) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_d) |> Repo.dagex_update()
      {:edge_removed, _edge} = TypeA.remove_edge(entity_a, entity_b) |> Repo.dagex_update()

      assert entity_d in (TypeA.descendants(entity_a) |> Repo.all())
    end
  end

  describe "children/1" do
    test "returns a list of nodes that are direct children of the given node" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_d} = %TypeA{name: "bar"} |> Repo.insert()
      {:ok, entity_e} = %TypeA{name: "bar"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_c) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_e) |> Repo.dagex_update()

      children = TypeA.children(entity_b) |> Repo.all()

      assert 2 == Enum.count(children)
      assert entity_c in children
      assert entity_d in children
    end

    test "returns an empty list if the given node has no children" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      assert [] == TypeA.children(entity_a) |> Repo.all()
    end
  end

  describe "parents/1" do
    test "returns a list of nodes that are direct parents of the given node" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()
      {:ok, entity_d} = %TypeA{name: "d"} |> Repo.insert()
      {:ok, entity_e} = %TypeA{name: "e"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_d, entity_e) |> Repo.dagex_update()

      parents = TypeA.parents(entity_d) |> Repo.all()

      assert 2 == Enum.count(parents)
      assert entity_b in parents
      assert entity_c in parents
    end

    test "returns an empty list if the given node has no parents" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      assert [] == TypeA.parents(entity_a) |> Repo.all()
    end
  end

  describe "ancestors/1" do
    test "returns a list of all ancestors of the given node" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()
      {:ok, entity_d} = %TypeA{name: "d"} |> Repo.insert()
      {:ok, entity_e} = %TypeA{name: "e"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_d, entity_e) |> Repo.dagex_update()

      ancestors = TypeA.ancestors(entity_d) |> Repo.all()

      assert 3 == Enum.count(ancestors)
      assert entity_a in ancestors
      assert entity_b in ancestors
      assert entity_c in ancestors
    end

    test "returns an empty list if the given node has no ancestors" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      assert [] == TypeA.ancestors(entity_a) |> Repo.all()
    end
  end

  describe "with_ancestors/1" do
    test "returns a list of all ancestors of the given node including the given node" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()
      {:ok, entity_d} = %TypeA{name: "d"} |> Repo.insert()
      {:ok, entity_e} = %TypeA{name: "e"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_d, entity_e) |> Repo.dagex_update()

      ancestors = TypeA.with_ancestors(entity_d) |> Repo.all()

      assert 4 == Enum.count(ancestors)
      assert entity_a in ancestors
      assert entity_b in ancestors
      assert entity_c in ancestors
      assert entity_d in ancestors
    end

    test "returns a list containing only the given node if the given node has no ancestors" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      assert [entity_a] == TypeA.with_ancestors(entity_a) |> Repo.all()
    end
  end

  describe "descendants/1" do
    test "returns a list of nodes that are descendants of the given node" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()
      {:ok, entity_d} = %TypeA{name: "d"} |> Repo.insert()
      {:ok, entity_e} = %TypeA{name: "e"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_c) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_e) |> Repo.dagex_update()

      descendants = TypeA.descendants(entity_b) |> Repo.all()

      assert 3 == Enum.count(descendants)
      assert entity_c in descendants
      assert entity_d in descendants
      assert entity_e in descendants
    end

    test "returns an empty list if the given node has no children" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      assert [] == TypeA.descendants(entity_a) |> Repo.all()
    end
  end

  describe "with_descendants/1" do
    test "returns a list of nodes that are descendants of the given node and includes the given node" do
      {:ok, entity_a} = %TypeA{name: "a"} |> Repo.insert()
      {:ok, entity_b} = %TypeA{name: "b"} |> Repo.insert()
      {:ok, entity_c} = %TypeA{name: "c"} |> Repo.insert()
      {:ok, entity_d} = %TypeA{name: "d"} |> Repo.insert()
      {:ok, entity_e} = %TypeA{name: "e"} |> Repo.insert()
      {:edge_created, _edge} = TypeA.create_edge(entity_a, entity_b) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_c) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_b, entity_d) |> Repo.dagex_update()
      {:edge_created, _edge} = TypeA.create_edge(entity_c, entity_e) |> Repo.dagex_update()

      descendants = TypeA.with_descendants(entity_b) |> Repo.all()

      assert 4 == Enum.count(descendants)
      assert entity_b in descendants
      assert entity_c in descendants
      assert entity_d in descendants
      assert entity_e in descendants
    end

    test "returns a list containing only the given node if the given node has no children" do
      {:ok, entity_a} = %TypeA{name: "bar"} |> Repo.insert()
      assert [entity_a] == TypeA.with_descendants(entity_a) |> Repo.all()
    end
  end
end
