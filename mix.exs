defmodule Dagex.MixProject do
  use Mix.Project

  def project do
    [
      name: "dagex",
      description:
        "Implement directed, acyclic graphs for Ecto models using PostrgreSQL's ltree extension.",
      source_url: "https://github.com/jwilger/dagex",
      homepage_url: "https://github.com/jwilger/dagex",
      package: [
        licenses: ["Apache-2.0"],
        links: []
      ],
      app: :dagex,
      version: "1.0.0",
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
        extras: ["README.md", "LICENSE"],
        markdown_processor: {ExDoc.Markdown.Earmark, footnotes: true},
        before_closing_head_tag: &before_closing_head_tag/1
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

  defp before_closing_head_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        mermaid.initialize({ startOnLoad: false });
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition, function (svgSource, bindListeners) {
            graphEl.innerHTML = svgSource;
            bindListeners && bindListeners(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp before_closing_head_tag(_type), do: ""

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:assertions, "~> 0.19", only: :test},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:ex_doc, "~> 0.21", only: [:dev, :test], runtime: false},
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
