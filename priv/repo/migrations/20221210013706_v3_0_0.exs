defmodule DagexTest.Repo.Migrations.V300 do
  require Dagex.Migrations
  use Ecto.Migration

  def up do
    Dagex.Migrations.up(version: 3)

    Dagex.Migrations.setup_node_type("type_as", "3.0.0")
    Dagex.Migrations.setup_node_type("type_bs", "3.0.0")
    Dagex.Migrations.setup_node_type("animal_types", "3.0.0")
    Dagex.Migrations.setup_node_type("type_cs", "3.0.0")
    Dagex.Migrations.setup_node_type("type_ds", "3.0.0")
  end

  def down do
    Dagex.Migrations.setup_node_type("type_as", "2.0.0")
    Dagex.Migrations.setup_node_type("type_bs", "2.0.0")
    Dagex.Migrations.setup_node_type("animal_types", "2.0.0")
    Dagex.Migrations.setup_node_type("type_cs", "2.0.0")
    Dagex.Migrations.down(version: 3)
  end
end
