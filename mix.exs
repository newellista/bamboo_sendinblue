defmodule BambooSendinblue.Mixfile do
  use Mix.Project

  @project_url "https://github.com/newellista/bamboo_sendinblue"
  @version "0.1.0"

  def project do
    [
      app: :bamboo_sendinblue,
      version: @version,
      elixir: "~> 1.5",
      source_url: @project_url,
      homepage_url: @project_url,
      name: "Bamboo SendInBlue Adapter",
      description: "A Bamboo adapter for the SendInBlue email service",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
      docs: fn ->
        [
          source_ref: "v#{@version}",
          canonical: "http://hexdocs.pm/bamboo_sendinblue",
          main: "Bamboo SendInBlue Adapter",
          source_url: @project_url,
          extras: ["README.md", "CHANGELOG.md"],
        ]
      end,
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :bamboo]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bamboo, github: "thoughtbot/bamboo"},
      {:cowboy, "~> 1.0", only: [:test, :dev]},
    ]
  end

  defp package do
    [
      maintainers: ["Steve Newell"],
      licenses: ["MIT"],
      links: %{"Github" => @project_url}
    ]
  end
end
