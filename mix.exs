defmodule Dagex.MixProject do
  use Mix.Project

  def project do
    [
      name: "dagex",
      source_url: "https://github.com/jwilger/dagex",
      homepage_url: "https://github.com/jwilger/dagex",
      app: :dagex,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      preferred_cli_env: [
        "ecto.create": :test,
        "ecto.drop": :test,
        "ecto.dump": :test,
        "ecto.gen.migration": :test,
        "ecto.load": :test,
        "ecto.migrate": :test,
        "ecto.migrations": :test,
        "ecto.rollback": :test,
        "ecto.reset": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      docs: [
        main: "readme",
        extras: ["README.md"],
        markdown_processor: {ExDoc.Markdown.Earmark, footnotes: true}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:postgrex, ">= 0.0.0"},
      {:typed_ecto_schema, "~> 0.3"}
    ]
  end

  defp aliases do
    [
      "ecto.reset": ["ecto.drop --quiet", "ecto.create --quiet", "ecto.migrate --quiet"],
      test: ["ecto.reset", "test"]
    ]
  end
end
