defmodule DagexTest.AnimalType do
  use Ecto.Schema
  use Dagex

  schema "animal_types" do
    field(:name, :string)
    timestamps()
  end
end
