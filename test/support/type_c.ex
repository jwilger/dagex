defmodule DagexTest.TypeC do
  @moduledoc false

  use Dagex
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "type_cs" do
    field(:name, :string)
  end
end
