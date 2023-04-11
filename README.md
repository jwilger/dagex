# Dagex

Dagex provides tools to create directed, acyclic graphs for your business
entities. It relies on the [PostgreSQL ltree
extension](https://www.postgresql.org/docs/14/ltree.html) and
[Ecto](https://hexdocs.pm/ecto/Ecto.html).

See the module documentation for `Dagex` for usage examples.

## Installation

### 1. Add dependency

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `dagex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dagex, "~> 3.0"}
  ]
end
```

### 2. Add Dagex functionality to your Ecto repository:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
  use Dagex.Repo
end
```

### 3. Generate a migration to add the necessary database tables and functions

Run `mix ecto.gen.migration add_dagex_to_project` then edit the resulting
migration file:

```elixir
defmodule MyApp.Repo.Migrations.AddDagexToProject do
  use Ecto.Migration
  
  def up do
    Dagex.Migrations.up()
  end
  
  def down do 
    Dagex.Migrations.down()
  end
end
```

and then migrate your database with `mix ecto.migrate`.

### 4. Use migrations to create db tables for the business entities that participate in a DAG:

Run `mix ecto.gen.migration add_organizations` then edit the resulting migration
file:

```elixir
defmodule MyApp.Repo.Migrations.AddOrganizations do 
  require Dagex.Migrations

  use Ecto.Migration 
  
  def change do 
    create table("organizations") do
      add :name, :string, null: false
      timestamps()
    end
    
    # Adds triggers to the "organizations" table to maintain the associated DAG as
    # records are added/removed.
    Dagex.Migrations.setup_node_type("organizations", "3.0.0")
  end
end
```

### 5. Create your Ecto-backed entity and add Dagex functionality:

N.B. You can use any column type that Postgresql can convert to text as the
entity's primary key, however, if your primary key field is a string, you MUST
NOT allow the value `"*"` as this is reserved internally for the supremum of the
graph. You will see an `Ecto.ConstraintError` on the `dagex_reserved_supremum_id`
constraint if you attempt to insert such a record.

```elixir
defmodule MyApp.Organization do 
  use Dagex 
  use Ecto.Schema
  
  schema "organizations" do
    field :name, :string
  end
end
```

See the module documentation for `Dagex` for information on the functionality
that is added to your module when calling `use Dagex`.
