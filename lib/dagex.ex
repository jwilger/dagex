defmodule Dagex do
  @moduledoc ~S"""
  The `Dagex` library is used to allow your business entities to participate in
  directed, acyclic graphs backed by [PostgreSQL's ltree
  extenstion](https://www.postgresql.org/docs/14/ltree.html).

  ## Installation

  See the instructions in the project's [README](README.md) to perform initial
  setup of the required database tables and functions.

  ## Adding and manipulating a DAG for your business entity

  Let's say your application deals with classifying different types of animals.
  You may wish to model a set of animals as follows (taken from [a post by Kemal
  Erdogan](https://www.codeproject.com/Articles/22824/A-Model-to-Represent-Directed-Acyclic-Graphs-DAG-o#Figure3)):

  ```mermaid
  graph TD
    Animal --> Pet
    Animal --> Livestock
    Pet --> Cat
    Pet --> Dog
    Pet --> Sheep
    Dog --> Doberman
    Dog --> Bulldog
    Livestock --> Dog
    Livestock --> Sheep
    Livestock --> Cow
  ```

  Assuming you have configured Dagex as per the [README](README.md), we can go
  ahead and set up the Ecto model needed. First, run `mix ecto.gen.migration
  add_animal_types` and then edit the resulting migration file:

  ```elixir
  defmodule DagexTest.Repo.Migrations.AddAnimalTypes do
    require Dagex.Migrations

    def change do
      create table("animal_types") do
        add :name, :string, null: false
        timestamps()
      end

      create index("animal_types", :name, unique: true)
      Dagex.Migrations.setup_node_type("animal_types", "1.0.0")
    end
  end
  ```

  Run migrations with `mix ecto.migrate` and then create your model:

  ```elixir
  defmodule DagexTest.AnimalType do
    use Ecto.Schema
    use Dagex

    schema "animal_types" do
      field :name, :string
      timestamps()
    end
  end
  ```

  Now we can create the animal types and specify their associations in the DAG,
  and make queries about the graph itself:

      iex> alias DagexTest.{AnimalType, Repo}
      iex>
      iex> # allows us to compare the contents of two lists independent of order
      iex> import Assertions, only: [assert_lists_equal: 2]
      iex>
      iex> # Add a couple of nodes
      iex> {:ok, animal} = %AnimalType{name: "Animal"} |> Repo.insert()
      iex> {:ok, pet} = %AnimalType{name: "Pet"} |> Repo.insert()
      iex>
      iex> # Create an association between the nodes
      iex> {:edge_created, _edge} = AnimalType.create_edge(animal, pet) |> Repo.dagex_update()
      iex>
      iex> # Add the remaining nodes and create the associations as per the graph
      iex>
      iex> {:ok, livestock} = %AnimalType{name: "Livestock"} |> Repo.insert()
      iex> {:edge_created, _edge} = AnimalType.create_edge(animal, livestock) |> Repo.dagex_update()
      iex>
      iex> {:ok, cat} = %AnimalType{name: "Cat"} |> Repo.insert()
      iex> {:edge_created, _edge} = AnimalType.create_edge(pet, cat) |> Repo.dagex_update()
      iex>
      iex> # Note that a node may have multiple parents
      iex> {:ok, dog} = %AnimalType{name: "Dog"} |> Repo.insert()
      iex> {:edge_created, _edge} = AnimalType.create_edge(pet, dog) |> Repo.dagex_update()
      iex> {:edge_created, _edge} = AnimalType.create_edge(livestock, dog) |> Repo.dagex_update()
      iex>
      iex> {:ok, sheep} = %AnimalType{name: "Sheep"} |> Repo.insert()
      iex> {:edge_created, _edge} = AnimalType.create_edge(pet, sheep) |> Repo.dagex_update()
      iex> {:edge_created, _edge} = AnimalType.create_edge(livestock, sheep) |> Repo.dagex_update()
      iex>
      iex> {:ok, cow} = %AnimalType{name: "Cow"} |> Repo.insert()
      iex> {:edge_created, _edge} = AnimalType.create_edge(livestock, cow) |> Repo.dagex_update()
      iex>
      iex> {:ok, doberman} = %AnimalType{name: "Doberman"} |> Repo.insert()
      iex> {:edge_created, _edge} = AnimalType.create_edge(dog, doberman) |> Repo.dagex_update()
      iex>
      iex> {:ok, bulldog} = %AnimalType{name: "Bulldog"} |> Repo.insert()
      iex> {:edge_created, _edge} = AnimalType.create_edge(dog, bulldog) |> Repo.dagex_update()
      iex>
      iex> # we can get the direct children of a node:
      iex> children = AnimalType.children(animal) |> Repo.all()
      iex> assert_lists_equal(children, [pet, livestock])
      iex>
      iex> # we can get the direct parents of a node
      iex> parents = AnimalType.parents(dog) |> Repo.all()
      iex> assert_lists_equal(parents, [pet, livestock])
      iex>
      iex> # we can get all of the descendants of a node
      iex> descendants = AnimalType.descendants(pet) |> Repo.all()
      iex> assert_lists_equal(descendants, [cat, dog, sheep, doberman, bulldog])
      iex>
      iex> # we can get all ancestors of a node
      iex> ancestors = AnimalType.ancestors(bulldog) |> Repo.all()
      iex> assert_lists_equal(ancestors, [dog, pet, livestock, animal])
      iex>
      iex> # we can determine if node A precedes (i.e. is an ancestor of) node B
      iex> true = AnimalType.precedes?(pet, bulldog) |> Repo.exists?()
      iex> false = AnimalType.precedes?(sheep, bulldog) |> Repo.exists?()
      iex>
      iex> # and we can determine if node A succeeds (i.e. is a descendant of) node B
      iex> true = AnimalType.succeeds?(bulldog, pet) |> Repo.exists?()
      iex> false = AnimalType.succeeds?(bulldog, sheep) |> Repo.exists?()
      iex>
      iex> # if we remove an edge
      iex> {:edge_removed, _edge} = AnimalType.remove_edge(livestock, dog) |> Repo.dagex_update()
      iex> # then
      iex> false = AnimalType.succeeds?(bulldog, livestock) |> Repo.exists?()
      iex> false = AnimalType.precedes?(livestock, bulldog) |> Repo.exists?()
      iex>
      iex> # and if we remove a node entirely
      iex> Repo.delete!(livestock)
      iex> # then
      iex> [] = AnimalType.ancestors(cow) |> Repo.all()
      iex> assert_lists_equal([dog, pet, animal], AnimalType.ancestors(bulldog) |> Repo.all())
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Dagex.Operations.{CreateEdge, RemoveEdge}

  @doc false
  @spec roots(module()) :: Ecto.Queryable.t()
  def roots(module) do
    node_type = module.__schema__(:source)
    primary_key_field = module.__schema__(:primary_key) |> List.first()

    from(r in module,
      join: n in "dagex_nodes",
      on: n.ext_id == fragment("?::text", field(r, ^primary_key_field)),
      join: p in "dagex_paths",
      on: p.node_id == n.id,
      where: p.path == fragment("text2ltree(?::text)", n.id) and n.node_type == ^node_type
    )
  end

  @doc false
  @spec children(module(), struct()) :: Ecto.Queryable.t()
  def children(module, parent) do
    node_type = module.__schema__(:source)
    primary_key_field = module.__schema__(:primary_key) |> List.first()
    parent_id = Map.fetch!(parent, primary_key_field) |> to_string()

    from(
      children in module,
      join: child_nodes in "dagex_nodes",
      on: child_nodes.ext_id == fragment("?::text", field(children, ^primary_key_field)),
      join: paths in "dagex_paths",
      on: child_nodes.id == paths.node_id,
      join: parent_nodes in "dagex_nodes",
      on: fragment("? ~ CAST('*.' || ?::text || '.*{1}' AS lquery)", paths.path, parent_nodes.id),
      where:
        parent_nodes.ext_id == ^parent_id and parent_nodes.node_type == ^node_type and
          child_nodes.node_type == ^node_type
    )
  end

  @doc false
  @spec descendants(module(), struct()) :: Ecto.Queryable.t()
  def descendants(module, parent) do
    node_type = module.__schema__(:source)
    primary_key_field = module.__schema__(:primary_key) |> List.first()
    parent_id = Map.fetch!(parent, primary_key_field) |> to_string()

    from(
      descendants in module,
      distinct: descendants.id,
      join: descendant_nodes in "dagex_nodes",
      on: descendant_nodes.ext_id == fragment("?::text", descendants.id),
      join: descendant_paths in "dagex_paths",
      on: descendant_paths.node_id == descendant_nodes.id,
      join: parent_paths in "dagex_paths",
      on: fragment("? <@ ?", descendant_paths.path, parent_paths.path),
      join: parent_nodes in "dagex_nodes",
      on: parent_nodes.id == parent_paths.node_id,
      where:
        parent_nodes.ext_id == fragment("?::text", ^parent_id) and
          parent_nodes.node_type == ^node_type and
          descendant_nodes.node_type == ^node_type and
          descendant_nodes.id != parent_nodes.id
    )
  end

  @doc false
  @spec succeeds?(module(), struct(), struct()) :: Ecto.Queryable.t()
  def succeeds?(module, descendant, ancestor) do
    primary_key_field = module.__schema__(:primary_key) |> List.first()
    descendant_id = Map.fetch!(descendant, primary_key_field)

    descendants(module, ancestor)
    |> where([m], field(m, ^primary_key_field) == ^descendant_id)
  end

  @doc false
  @spec parents(module(), struct()) :: Ecto.Queryable.t()
  def parents(module, child) do
    node_type = module.__schema__(:source)
    primary_key_field = module.__schema__(:primary_key) |> List.first()
    child_id = Map.fetch!(child, primary_key_field) |> to_string()

    from(
      ancestors in module,
      join: ancestor_nodes in "dagex_nodes",
      on: ancestor_nodes.ext_id == fragment("?::text", ancestors.id),
      join: ancestor_paths in "dagex_paths",
      on: ancestor_paths.node_id == ancestor_nodes.id,
      join: child_paths in "dagex_paths",
      on: child_paths.path == fragment("? || ?::text", ancestor_paths.path, child_paths.node_id),
      join: child_nodes in "dagex_nodes",
      on: child_nodes.id == child_paths.node_id,
      where:
        child_nodes.ext_id == fragment("?::text", ^child_id) and
          ancestor_nodes.node_type == ^node_type and
          child_nodes.node_type == ^node_type
    )
  end

  @doc false
  @spec ancestors(module(), struct()) :: Ecto.Queryable.t()
  def ancestors(module, child) do
    node_type = module.__schema__(:source)
    primary_key_field = module.__schema__(:primary_key) |> List.first()
    child_id = Map.fetch!(child, primary_key_field) |> to_string()

    from(
      ancestors in module,
      distinct: ancestors.id,
      join: ancestor_nodes in "dagex_nodes",
      on: ancestor_nodes.ext_id == fragment("?::text", ancestors.id),
      join: ancestor_paths in "dagex_paths",
      on: ancestor_paths.node_id == ancestor_nodes.id,
      join: child_paths in "dagex_paths",
      on: fragment("? @> ?", ancestor_paths.path, child_paths.path),
      join: child_nodes in "dagex_nodes",
      on: child_nodes.id == child_paths.node_id,
      where:
        child_nodes.ext_id == fragment("?::text", ^child_id) and
          ancestor_nodes.node_type == ^node_type and
          child_nodes.node_type == ^node_type and
          ancestor_nodes.id != child_nodes.id
    )
  end

  @doc false
  @spec precedes?(module(), struct(), struct()) :: Ecto.Queryable.t()
  def precedes?(module, ancestor, descendant) do
    primary_key_field = module.__schema__(:primary_key) |> List.first()
    ancestor_id = Map.fetch!(ancestor, primary_key_field)

    ancestors(module, descendant)
    |> where([m], field(m, ^primary_key_field) == ^ancestor_id)
  end

  @doc false
  @spec create_edge(struct(), struct()) :: CreateEdge.t()
  def create_edge(parent, child) do
    CreateEdge.new(parent, child)
  end

  @doc false
  @spec remove_edge(struct(), struct()) :: RemoveEdge.t()
  def remove_edge(parent, child) do
    RemoveEdge.new(parent, child)
  end

  @doc false
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(_opts) do
    caller_module = __CALLER__.module |> to_string() |> String.replace_leading("Elixir.", "")

    quote generated: true, bind_quoted: [caller_module: caller_module] do
      @doc """
      Returns a query that can be passed to your application's Ecto repository
      to retrieve a list of entities of the type defined in this module that are
      at the top level of the DAG (i.e. have no other parents.)

      ## Example

          iex> [a_root_entity | _rest] #{caller_module}.roots() |> Repo.all()
          iex> #{caller_module}.parents(a_root_entity) |> Repo.all()
          []
      """
      @spec roots() :: Ecto.Queryable.t()
      def roots, do: Dagex.roots(__MODULE__)

      @doc """
      Returns a query that can be passed to your application's Ecto repository
      to retrieve a list of entities that are children of the specified parent
      entity.

      ## Example

          iex> {:ok, entity_a} = %#{caller_module}{name: "a"} |> Repo.insert()
          iex> {:ok, entity_b} = %#{caller_module}{name: "b"} |> Repo.insert()
          iex> {:ok, entity_c} = %#{caller_module}{name: "c"} |> Repo.insert()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_a, entity_b)
          ...>   |> Repo.dagex_update()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_a, entity_c)
          ...>   |> Repo.dagex_update()
          iex> #{caller_module}.children(entity_a) |> Repo.all()
          [entity_b, entity_c]

      """
      @spec children(%__MODULE__{}) :: Ecto.Queryable.t()
      def children(parent), do: Dagex.children(__MODULE__, parent)

      @doc """
      Returns a query that can be passed to your application's Ecto repository
      to retrieve a list of entities that are descendants of the specified parent
      entity.

      ## Example

          iex> {:ok, entity_a} = %#{caller_module}{name: "a"} |> Repo.insert()
          iex> {:ok, entity_b} = %#{caller_module}{name: "b"} |> Repo.insert()
          iex> {:ok, entity_c} = %#{caller_module}{name: "c"} |> Repo.insert()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_a, entity_b)
          ...>   |> Repo.dagex_update()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_b, entity_c)
          ...>   |> Repo.dagex_update()
          iex> #{caller_module}.descendants(entity_a) |> Repo.all()
          [entity_b, entity_c]

      """
      @spec descendants(%__MODULE__{}) :: Ecto.Queryable.t()
      def descendants(parent), do: Dagex.descendants(__MODULE__, parent)

      @doc """
      Returns a query that selects descendant only if descendant is a descendant
      of ancestor.

      ## Example

          iex> {:ok, entity_a} = %#{caller_module}{name: "a"} |> Repo.insert()
          iex> {:ok, entity_b} = %#{caller_module}{name: "b"} |> Repo.insert()
          iex> {:ok, entity_c} = %#{caller_module}{name: "c"} |> Repo.insert()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_a, entity_b)
          ...>   |> Repo.dagex_update()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_b, entity_c)
          ...>   |> Repo.dagex_update()
          iex> #{caller_module}.succeeds?(entity_c, entity_a) |> Repo.one()
          entity_c
          iex> #{caller_module}.succeeds?(entity_a, entity_c) |> Repo.one()
          nil
      """
      @spec succeeds?(descendant :: %__MODULE__{}, ancestor :: %__MODULE__{}) ::
              Ecto.Queryable.t()
      def succeeds?(descendant, ancestor), do: Dagex.succeeds?(__MODULE__, descendant, ancestor)

      @doc """
      Returns a query that can be passed to your application's Ecto repository
      to retrieve a list of entities that are parents of the specified child
      entity.

      ## Example

          iex> {:ok, entity_a} = %#{caller_module}{name: "a"} |> Repo.insert()
          iex> {:ok, entity_b} = %#{caller_module}{name: "b"} |> Repo.insert()
          iex> {:ok, entity_c} = %#{caller_module}{name: "c"} |> Repo.insert()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_a, entity_c)
          ...>   |> Repo.dagex_update()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_b, entity_c)
          ...>   |> Repo.dagex_update()
          iex> #{caller_module}.parents(entity_c) |> Repo.all()
          [entity_a, entity_b]

      """
      @spec parents(%__MODULE__{}) :: Ecto.Queryable.t()
      def parents(child), do: Dagex.parents(__MODULE__, child)

      @doc """
      Returns a query that can be passed to your application's Ecto repository
      to retrieve a list of entities that are ancestors of the specified child
      entity.

      ## Example

          iex> {:ok, entity_a} = %#{caller_module}{name: "a"} |> Repo.insert()
          iex> {:ok, entity_b} = %#{caller_module}{name: "b"} |> Repo.insert()
          iex> {:ok, entity_c} = %#{caller_module}{name: "c"} |> Repo.insert()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_a, entity_b)
          ...>   |> Repo.dagex_update()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_b, entity_c)
          ...>   |> Repo.dagex_update()
          iex> #{caller_module}.ancestors(entity_c) |> Repo.all()
          [entity_a, entity_b]

      """
      @spec ancestors(%__MODULE__{}) :: Ecto.Queryable.t()
      def ancestors(child), do: Dagex.ancestors(__MODULE__, child)

      @doc """
      Returns a query that selects ancestor only if ancestor is an ancestor
      of descendant.

      ## Example

          iex> {:ok, entity_a} = %#{caller_module}{name: "a"} |> Repo.insert()
          iex> {:ok, entity_b} = %#{caller_module}{name: "b"} |> Repo.insert()
          iex> {:ok, entity_c} = %#{caller_module}{name: "c"} |> Repo.insert()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_a, entity_b)
          ...>   |> Repo.dagex_update()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_b, entity_c)
          ...>   |> Repo.dagex_update()
          iex> #{caller_module}.precedes?(entity_c, entity_a) |> Repo.one()
          nil
          iex> #{caller_module}.succeeds?(entity_a, entity_c) |> Repo.one()
          entity_a
      """
      @spec precedes?(ancestor :: %__MODULE__{}, descendant :: %__MODULE__{}) ::
              Ecto.Queryable.t()
      def precedes?(ancestor, descendant), do: Dagex.precedes?(__MODULE__, ancestor, descendant)

      @doc """
      Returns a `Dagex.Operations.CreateEdge` struct to be passed to
      `Dagex.Repo.dagex_update/2` that will attempt to create a new edge in
      `#{caller_module}`'s DAG.

      ## Example

          iex> {:ok, entity_a} = %#{caller_module}{name: "a"} |> Repo.insert()
          iex> {:ok, entity_b} = %#{caller_module}{name: "b"} |> Repo.insert()
          iex> #{caller_module}.create_edge(entity_a, entity_b) |> Repo.dagex_update()
          {:edge_created, {entity_a, entity_b}}
      """
      @spec create_edge(%__MODULE__{}, %__MODULE__{}) :: CreateEdge.t()
      defdelegate create_edge(parent, child), to: Dagex

      @doc """
      Returns a `Dagex.Operations.RemoveEdge` struct to be passed to
      `Dagex.Repo.dagex_update/2` that will attempt to remove the specified edge
      from `#{caller_module}`'s DAG.

      ## Example

          iex> {:ok, entity_a} = %#{caller_module}{name: "a"} |> Repo.insert()
          iex> {:ok, entity_b} = %#{caller_module}{name: "b"} |> Repo.insert()
          iex> {:edge_created, _edge} = #{caller_module}.create_edge(entity_a, entity_b)
          ...>   |> Repo.dagex_update()
          iex> #{caller_module}.remove_edge(entity_a, entity_b) |> Repo.dagex_update()
          {:edge_removed, {entity_a, entity_b}}
      """
      @spec remove_edge(%__MODULE__{}, %__MODULE__{}) :: RemoveEdge.t()
      defdelegate remove_edge(parent, child), to: Dagex
    end
  end
end
