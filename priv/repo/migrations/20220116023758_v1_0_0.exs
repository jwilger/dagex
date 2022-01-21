defmodule Dagex.TestRepo.Migrations.V1_0_0 do
  @moduledoc false

  require Dagex.Migrations
  use Ecto.Migration

  def up do
    Dagex.Migrations.up()

    create table("type_as") do
      add(:foo, :string)
    end

    Dagex.Migrations.setup_node_type("type_as", "1.0.0")

    create table("type_bs") do
      add(:foo, :string)
    end

    Dagex.Migrations.setup_node_type("type_bs", "1.0.0")

    create table("animal_types") do
      add(:name, :string)
      timestamps()
    end

    create(index("animal_types", :name, unique: true))
    Dagex.Migrations.setup_node_type("animal_types", "1.0.0")
  end

  def down do
    drop(table("type_as"))
    drop(table("type_bs"))
    Dagex.Migrations.down()
  end
end
