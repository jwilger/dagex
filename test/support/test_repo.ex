defmodule DAGEx.TestRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :dagex, adapter: Ecto.Adapters.Postgres
end
