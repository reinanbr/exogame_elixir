defmodule BenchmarkPhoenix.MixProject do
  use Mix.Project

  def project do
    [
      app: :benchmark_phoenix,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        benchmark_phoenix: [
          strip_beams: true
        ]
      ]
    ]
  end

  def application do
    [mod: {BenchmarkPhoenix.Application, []}, extra_applications: [:logger]]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.5"},
      {:postgrex, "~> 0.19"},
      {:phoenix_pubsub, "~> 2.1"}
    ]
  end
end
