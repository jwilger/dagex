defmodule Dagex.Operations.RemoveEdge do
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

  @doc false
  @spec process_result(:ok, t()) :: {:edge_removed, {parent :: struct(), child :: struct()}}
  def process_result(:ok, op) do
    {:edge_removed, {op.parent, op.child}}
  end
end
