import Config

case Mix.env() do
  :test ->
    config :dagex, ecto_repos: [DagexTest.Repo]

  _env ->
    nil
end
