defmodule DagexTest.TypeA do
  @moduledoc false

  use Dagex
  use Ecto.Schema

  schema "type_as" do
    field(:name, :string)
  end
end
