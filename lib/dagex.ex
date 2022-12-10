defmodule Dagex do
  @moduledoc ~S"""
  The `Dagex` library is used to allow your business entities to participate in
  directed, acyclic graphs backed by [PostgreSQL's ltree
  extenstion](https://www.postgresql.org/docs/14/ltree.html).

  N.B. The callbacks defined in this module are automatically defined for you on
  your Ecto models when you `use Dagex` inside them.

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
    def change do
      create table("animal_types") do
        add :name, :string, null: false
        timestamps()
      end

      create index("animal_types", :name, unique: true)
      Dagex.Migrations.setup_node_type("animal_types", "2.0.0")
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
      iex> # we can also get the descendants including the node itself
      iex> descendants = AnimalType.with_descendants(pet) |> Repo.all()
      iex> assert_lists_equal(descendants, [pet, cat, dog, sheep, doberman, bulldog])
      iex>
      iex> # we can get all ancestors of a node
      iex> ancestors = AnimalType.ancestors(bulldog) |> Repo.all()
      iex> assert_lists_equal(ancestors, [dog, pet, livestock, animal])
      iex>
      iex> # we can also get the ancestors including the node itself
      iex> ancestors = AnimalType.with_ancestors(bulldog) |> Repo.all()
      iex> assert_lists_equal(ancestors, [bulldog, dog, pet, livestock, animal])
      iex>
      iex> # we can determine if node A precedes (i.e. is an ancestor of) node B
      iex> true = AnimalType.precedes?(pet, bulldog) |> Repo.exists?()
      iex> false = AnimalType.precedes?(sheep, bulldog) |> Repo.exists?()
      iex>
      iex> # and we can determine if node A succeeds (i.e. is a descendant of) node B
      iex> true = AnimalType.succeeds?(bulldog, pet) |> Repo.exists?()
      iex> false = AnimalType.succeeds?(bulldog, sheep) |> Repo.exists?()
      iex>
      iex> # we can also get the possible paths between two nodes
      iex> paths = AnimalType.all_paths(animal, sheep) |> Repo.dagex_paths()
      iex> assert_lists_equal(paths, [[animal, pet, sheep], [animal, livestock, sheep]])
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
      distinct: r.id,
      join: n in "dagex_nodes",
      on: n.ext_id == fragment("?::text", field(r, ^primary_key_field)),
      join: p in "dagex_paths",
      on: p.node_id == n.id,
      where: p.path == fragment("text2ltree(?::text)", n.id) and n.node_type == ^node_type,
      order_by: field(r, ^primary_key_field)
    )
  end

  @doc """
  Returns a query that can be passed to your application's Ecto repository
  to retrieve a list of entities of the type defined in this module that are
  at the top level of the DAG (i.e. have no other parents.)
  """
  @callback roots() :: Ecto.Queryable.t()

  @doc false
  @spec children(module(), struct()) :: Ecto.Queryable.t()
  def children(module, parent) do
    node_type = module.__schema__(:source)
    primary_key_field = module.__schema__(:primary_key) |> List.first()
    parent_id = Map.fetch!(parent, primary_key_field) |> to_string()

    from(
      children in module,
      distinct: children.id,
      join: child_nodes in "dagex_nodes",
      on: child_nodes.ext_id == fragment("?::text", field(children, ^primary_key_field)),
      join: paths in "dagex_paths",
      on: child_nodes.id == paths.node_id,
      join: parent_nodes in "dagex_nodes",
      on: fragment("? ~ CAST('*.' || ?::text || '.*{1}' AS lquery)", paths.path, parent_nodes.id),
      where:
        parent_nodes.ext_id == ^parent_id and parent_nodes.node_type == ^node_type and
          child_nodes.node_type == ^node_type,
      order_by: field(children, ^primary_key_field)
    )
  end

  @doc """
  Returns a query that can be passed to your application's Ecto repository
  to retrieve a list of entities that are children of the specified parent
  entity.
  """
  @callback children(parent :: Ecto.Schema.t()) :: Ecto.Queryable.t()

  @doc false
  @spec descendants(module(), struct()) :: Ecto.Queryable.t()
  def descendants(module, parent) do
    from([d, dn, dp, pp, pn] in with_descendants(module, parent),
      where: dn.id != pn.id
    )
  end

  @doc """
  Returns a query that can be passed to your application's Ecto repository
  to retrieve a list of entities that are descendants of the specified parent
  entity.
  """
  @callback descendants(parent :: Ecto.Schema.t()) :: Ecto.Queryable.t()

  @doc false
  @spec with_descendants(module(), struct()) :: Ecto.Queryable.t()
  def with_descendants(module, parent) do
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
          descendant_nodes.node_type == ^node_type,
      order_by: field(descendants, ^primary_key_field)
    )
  end

  @doc """
  Returns a query that can be passed to your application's Ecto repository
  to retrieve a list of entities that are descendants of the specified parent
  entity along with the parent entity itself.
  """
  @callback with_descendants(parent :: Ecto.Schema.t()) :: Ecto.Queryable.t()

  @doc false
  @spec succeeds?(module(), struct(), struct()) :: Ecto.Queryable.t()
  def succeeds?(module, descendant, ancestor) do
    primary_key_field = List.first(module.__schema__(:primary_key))
    descendant_id = Map.fetch!(descendant, primary_key_field)

    module
    |> descendants(ancestor)
    |> where([m], field(m, ^primary_key_field) == ^descendant_id)
  end

  @doc """
  Returns a query that selects descendant only if descendant is a descendant
  of ancestor.
  """
  @callback succeeds?(descendant :: Ecto.Schema.t(), ancestor :: Ecto.Schema.t()) ::
              Ecto.Queryable.t()

  @doc false
  @spec parents(module(), struct()) :: Ecto.Queryable.t()
  def parents(module, child) do
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
      on: child_paths.path == fragment("? || ?::text", ancestor_paths.path, child_paths.node_id),
      join: child_nodes in "dagex_nodes",
      on: child_nodes.id == child_paths.node_id,
      where:
        child_nodes.ext_id == fragment("?::text", ^child_id) and
          ancestor_nodes.node_type == ^node_type and
          child_nodes.node_type == ^node_type,
      order_by: field(ancestors, ^primary_key_field)
    )
  end

  @doc """
  Returns a query that can be passed to your application's Ecto repository
  to retrieve a list of entities that are parents of the specified child
  entity.
  """
  @callback parents(child :: Ecto.Schema.t()) :: Ecto.Queryable.t()

  @doc false
  @spec ancestors(module(), struct()) :: Ecto.Queryable.t()
  def ancestors(module, child) do
    from([a, an, ap, cp, cn] in with_ancestors(module, child),
      where: an.id != cn.id
    )
  end

  @doc """
  Returns a query that can be passed to your application's Ecto repository
  to retrieve a list of entities that are ancestors of the specified child
  entity.
  """
  @callback ancestors(child :: Ecto.Schema.t()) :: Ecto.Queryable.t()

  @doc false
  @spec with_ancestors(module(), struct()) :: Ecto.Queryable.t()
  def with_ancestors(module, child) do
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
          child_nodes.node_type == ^node_type,
      order_by: field(ancestors, ^primary_key_field)
    )
  end

  @doc """
  Returns a query that can be passed to your application's Ecto repository
  to retrieve a list of entities that are ancestors of the specified child
  entity as well as the child entity itself.
  """
  @callback with_ancestors(child :: Ecto.Schema.t()) :: Ecto.Queryable.t()

  @doc false
  @spec precedes?(module(), struct(), struct()) :: Ecto.Queryable.t()
  def precedes?(module, ancestor, descendant) do
    primary_key_field = List.first(module.__schema__(:primary_key))
    ancestor_id = Map.fetch!(ancestor, primary_key_field)

    module
    |> ancestors(descendant)
    |> where([m], field(m, ^primary_key_field) == ^ancestor_id)
  end

  @doc """
  Returns a query that selects ancestor only if ancestor is an ancestor
  of descendant.
  """
  @callback precedes?(ancestor :: Ecto.Schema.t(), descendant :: Ecto.Schema.t()) ::
              Ecto.Queryable.t()

  @doc false
  @spec create_edge(struct(), struct()) :: CreateEdge.t()
  def create_edge(parent, child) do
    CreateEdge.new(parent, child)
  end

  @doc """
  Returns a `Dagex.Operations.CreateEdge` struct to be passed to
  `c:Dagex.Repo.dagex_update/1` that will attempt to create a new edge in
  the implementing module's associated DAG.
  """
  @callback create_edge(parent :: Ecto.Schema.t(), child :: Ecto.Schema.t()) :: CreateEdge.t()

  @doc false
  @spec remove_edge(struct(), struct()) :: RemoveEdge.t()
  def remove_edge(parent, child) do
    RemoveEdge.new(parent, child)
  end

  @doc """
  Returns a `Dagex.Operations.RemoveEdge` struct to be passed to
  `c:Dagex.Repo.dagex_update/1` that will attempt to remove the specified edge
  from the implementing module's associated DAG.
  """
  @callback remove_edge(parent :: Ecto.Schema.t(), child :: Ecto.Schema.t()) :: RemoveEdge.t()

  @doc false
  @spec all_paths(module(), Ecto.Schema.t(), Ecto.Schema.t()) :: Ecto.Queryable.t()
  def all_paths(module, ancestor, descendant) do
    node_type = module.__schema__(:source)
    primary_key_field = List.first(module.__schema__(:primary_key))
    ancestor_id = ancestor |> Map.fetch!(primary_key_field) |> to_string()
    descendant_id = descendant |> Map.fetch!(primary_key_field) |> to_string()

    from(p in "dagex_paths",
      join: n in "dagex_nodes",
      on: n.id == p.node_id,
      join: an in "dagex_nodes",
      on: fragment("? ~ CAST('*.' || ? || '.*' AS lquery)", p.path, an.id),
      left_lateral_join:
        a in fragment(
          "SELECT a.elem, a.nr FROM unnest(string_to_array(?::text, '.')::int[]) WITH ORDINALITY AS a(elem, nr)",
          p.path
        ),
      on: true,
      join: part_node in "dagex_nodes",
      on: part_node.id == a.elem,
      join: m_node in ^module,
      on: fragment("?::text", m_node.id) == part_node.ext_id,
      where:
        n.ext_id == fragment("?::text", ^descendant_id) and
          n.node_type == ^node_type and
          an.ext_id == fragment("?::text", ^ancestor_id) and
          an.node_type == ^node_type,
      select: %{path: p.path, position: a.nr, node: m_node},
      order_by: [p.path, a.nr]
    )
  end

  @doc """
  Returns a query that can be passed to your application's Ecto repository's
  `c:Dagex.Repo.dagex_paths/1` function in order to retrieve a list of the
  possible paths between two nodes. Each path is itself a list starting with the
  `ancestor` node, ending with the `descendant` node, and including each node in
  the path between the two. Returns an empty list if no path exists between the
  two nodes.
  """
  @callback all_paths(ancestor :: Ecto.Schema.t(), descendant :: Ecto.Schema.t()) ::
              Ecto.Queryable.t()

  @doc false
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(_opts) do
    caller_module = __CALLER__.module |> to_string() |> String.replace_leading("Elixir.", "")

    quote generated: true, bind_quoted: [caller_module: caller_module] do
      @behaviour Dagex

      @impl Dagex
      def roots, do: Dagex.roots(__MODULE__)

      @impl Dagex
      def children(parent), do: Dagex.children(__MODULE__, parent)

      @impl Dagex
      def descendants(parent), do: Dagex.descendants(__MODULE__, parent)

      @impl Dagex
      def with_descendants(parent), do: Dagex.with_descendants(__MODULE__, parent)

      @impl Dagex
      def succeeds?(descendant, ancestor), do: Dagex.succeeds?(__MODULE__, descendant, ancestor)

      @impl Dagex
      def parents(child), do: Dagex.parents(__MODULE__, child)

      @impl Dagex
      def ancestors(child), do: Dagex.ancestors(__MODULE__, child)

      @impl Dagex
      def with_ancestors(child), do: Dagex.with_ancestors(__MODULE__, child)

      @impl Dagex
      def precedes?(ancestor, descendant), do: Dagex.precedes?(__MODULE__, ancestor, descendant)

      @impl Dagex
      def all_paths(ancestor, descendant), do: Dagex.all_paths(__MODULE__, ancestor, descendant)

      @impl Dagex
      defdelegate create_edge(parent, child), to: Dagex

      @impl Dagex
      defdelegate remove_edge(parent, child), to: Dagex
    end
  end
end
