defmodule DagexTest.TypeB do
  @moduledoc false

  use Dagex
  use Ecto.Schema

  schema "type_bs" do
    field(:name, :string)
  end
end
