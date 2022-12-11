defmodule DagexTest.Repo.Migrations.V301 do
  require Dagex.Migrations
  use Ecto.Migration

  def up do
    Dagex.Migrations.up(version: 4)
  end

  def down do
    Dagex.Migrations.down(version: 4)
  end
end
