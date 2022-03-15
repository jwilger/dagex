defmodule Dagex.Repo do
  @moduledoc """
  Adds Dagex-specific functionality to your application's `Ecto.Repo` module.

  ```elixir
  defmodule MyApp.Repo do
    use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
    use Dagex.Repo
  end
  ```
  """
  alias Dagex.Operations.{CreateEdge, RemoveEdge}

  @spec dagex_update(Ecto.Repo.t(), CreateEdge.t()) :: {:ok, tuple()} | {:error, term()}
  def dagex_update(_repo, {:error, _reason} = error), do: error

  def dagex_update(repo, %CreateEdge{} = op) do
    result =
      case repo.query("SELECT dagex_create_edge($1, $2, $3)", [
             op.node_type,
             op.parent_id,
             op.child_id
           ]) do
        {:ok, _result} ->
          :ok

        {:error, %Postgrex.Error{postgres: %{constraint: constraint_name}}}
        when is_bitstring(constraint_name) ->
          {:error, constraint_name}
      end

    CreateEdge.process_result(result, op)
  end

  def dagex_update(repo, %RemoveEdge{} = op) do
    result =
      case repo.query("SELECT dagex_remove_edge($1, $2, $3)", [
             op.node_type,
             op.parent_id,
             op.child_id
           ]) do
        {:ok, _result} ->
          :ok

        {:error, %Postgrex.Error{postgres: %{constraint: constraint_name}}}
        when is_bitstring(constraint_name) ->
          {:error, constraint_name}
      end

    RemoveEdge.process_result(result, op)
  end

  def dagex_paths(repo, queryable) do
    queryable
    |> repo.all()
    |> Enum.group_by(fn node -> node.path end)
    |> Enum.map(fn {_path, nodes} ->
      nodes
      |> Enum.sort(&(&1.position <= &2.position))
      |> Enum.map(fn node -> node.node end)
    end)
  end

  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      def dagex_update(operation), do: Dagex.Repo.dagex_update(__MODULE__, operation)

      def dagex_paths(queryable), do: Dagex.Repo.dagex_paths(__MODULE__, queryable)
    end
  end
end
