defmodule Dagex.TestRepo.Migrations.V1_3_0 do
  @moduledoc false

  require Dagex.Migrations
  use Ecto.Migration

  def up do
    Dagex.Migrations.up(version: 2)

    Dagex.Migrations.setup_node_type("type_as", "2.0.0")
    Dagex.Migrations.setup_node_type("type_bs", "2.0.0")
    Dagex.Migrations.setup_node_type("animal_types", "2.0.0")
    Dagex.Migrations.setup_node_type("type_cs", "2.0.0")

    create table("type_ds", primary_key: false) do
      add(:id, :string, null: false, primary_key: true)
      add(:name, :string)
    end

    create(index("type_ds", :name, unique: true))
    Dagex.Migrations.setup_node_type("type_ds", "2.0.0")
  end

  def down do
    drop(table("type_ds"))
    Dagex.Migrations.setup_node_type("type_as", "1.0.0")
    Dagex.Migrations.setup_node_type("type_bs", "1.0.0")
    Dagex.Migrations.setup_node_type("animal_types", "1.0.0")
    Dagex.Migrations.setup_node_type("type_cs", "1.0.0")
    Dagex.Migrations.down(version: 2)
  end
end
