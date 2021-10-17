defmodule Realleasy.MixProject do
  use Mix.Project

  def project do
    [
      app: :realleasy,
      version: "0.2.2",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Realleasy",
      source_url: "https://github.com/maxdrift/realleasy",
      homepage_url: "https://github.com/maxdrift/realleasy",
      docs: [
        main: "Realleasy",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:hackney, "~> 1.17"},
      {:jason, "~> 1.0"},
      {:tesla, "~> 1.4"}
    ]
  end

  defp description() do
    "Mix task to generate a log of changes from merged pull requests."
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/maxdrift/realleasy"},
      source_url: "https://github.com/maxdrift/realleasy",
      homepage_url: "https://github.com/maxdrift/realleasy"
    ]
  end
end
