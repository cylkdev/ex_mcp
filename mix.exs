defmodule ExMCP.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_mcp,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ExMCP",
      docs: docs()
    ]
  end

  defp docs do
    [
      main: "ExMCP",
      extras: ["README.md"],
      groups_for_modules: [
        Transport: [ExMCP.Stdio],
        Core: [ExMCP.Server, ExMCP.Protocol, ExMCP.Registry, ExMCP.Config],
        Tools: [ExMCP.Tool, ExMCP.Tool.Context],
        Notifications: [ExMCP.Notifier, ExMCP.Notifier.Null, ExMCP.Notifier.Stdio]
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
