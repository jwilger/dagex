{:ok, _pid} = DagexTest.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(DagexTest.Repo, :manual)

ExUnit.start()
