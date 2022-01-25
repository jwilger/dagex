defmodule DagexTest.TypeB do
  use Dagex
  use Ecto.Schema

  schema "type_bs" do
    field(:name, :string)
  end
end
