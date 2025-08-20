defmodule ZigDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :zig_demo,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools, :wx, :observer]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zigler, "~> 0.14.1", runtime: false},
      {:iptrie, "~> 0.10"},
      {:benchee, "~> 1.4", only: :dev}
    ]
  end
end
