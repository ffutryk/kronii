defmodule Kronii.MixProject do
  use Mix.Project

  def project do
    [
      app: :kronii,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :plug_cowboy],
      mod: {Kronii.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_ulid, "~> 0.1.0"},
      {:req, "~> 0.5.0"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:anubis_mcp, "~> 0.16.0"}
    ]
  end
end
