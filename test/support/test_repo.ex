defmodule DagexTest.Repo do
  @moduledoc false

  use Ecto.Repo, otp_app: :dagex, adapter: Ecto.Adapters.Postgres
  use Dagex.Repo
end
