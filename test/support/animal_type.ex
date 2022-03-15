defmodule DagexTest.AnimalType do
  @moduledoc false

  use Ecto.Schema
  use Dagex

  schema "animal_types" do
    field(:name, :string)
    timestamps()
  end
end
