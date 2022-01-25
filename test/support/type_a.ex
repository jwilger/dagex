defmodule DagexTest.TypeA do
  use Dagex
  use Ecto.Schema

  schema "type_as" do
    field(:name, :string)
  end
end
