import Config

case Mix.env() do
  :test ->
    config :dagex, ecto_repos: [DAGEx.TestRepo]

  _env ->
    nil
end
