defmodule DagexTest.TypeD do
  @moduledoc false

  use Dagex
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "type_ds" do
    field(:name, :string)
  end
end
