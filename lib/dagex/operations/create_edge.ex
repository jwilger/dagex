defmodule Dagex.Operations.CreateEdge do
  @moduledoc """
  Represents a database operation to create a new edge between two nodes.

  See `Dagex.create_edge/2`
  """

  @type t() :: %__MODULE__{
          node_type: String.t(),
          parent: struct(),
          parent_id: String.t(),
          child: struct(),
          child_id: String.t()
        }

  defstruct [:node_type, :parent, :parent_id, :child, :child_id]

  @doc false
  @spec new(struct(), struct()) :: t() | {:error, term()}
  def new(parent, child) do
    node_type = parent.__meta__.source

    if node_type != child.__meta__.source do
      {:error, :incompatible_nodes}
    else
      primary_key_field = parent.__struct__.__schema__(:primary_key) |> List.first()
      parent_id = Map.get(parent, primary_key_field) |> to_string()
      child_id = Map.get(child, primary_key_field) |> to_string()

      %__MODULE__{
        node_type: node_type,
        parent: parent,
        parent_id: parent_id,
        child: child,
        child_id: child_id
      }
    end
  end

  @doc false
  @spec process_result(:ok | {:error, String.t()}, t()) ::
          {:edge_created, {parent :: struct(), child :: struct()}} | {:error, reason :: atom()}
  def process_result(:ok, op) do
    {:edge_created, {op.parent, op.child}}
  end

  def process_result({:error, "dagex_paths_unique"}, op) do
    {:edge_created, {op.parent, op.child}}
  end

  def process_result({:error, "dagex_edge_constraint"}, _op) do
    {:error, :cyclic_edge}
  end

  def process_result({:error, "dagex_parent_exists_constraint"}, _op) do
    {:error, :parent_not_found}
  end

  def process_result({:error, "dagex_child_exists_constraint"}, _op) do
    {:error, :child_not_found}
  end
end
