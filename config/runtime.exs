import Config

case Mix.env() do
  :test ->
    config :dagex, DAGEx.TestRepo,
      adapter: Ecto.Adapters.Postgres,
      url: System.get_env("TEST_DATABASE_URL"),
      pool: Ecto.Adapters.SQL.Sandbox

    config :logger, level: String.to_existing_atom(System.get_env("LOG_LEVEL", "info"))

  _env ->
    nil
end
