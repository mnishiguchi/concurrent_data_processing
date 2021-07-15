defmodule ConcurrentDataProcessing.MixProject do
  use Mix.Project

  def project do
    [
      app: :concurrent_data_processing,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # Libraries that are available to us but not part of the Erlang standard library
      extra_applications: [:logger, :crypto],
      mod: {ConcurrentDataProcessing.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_stage, "~> 1.0"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
