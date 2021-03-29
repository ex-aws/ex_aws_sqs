defmodule ExAws.SQS.Mixfile do
  use Mix.Project

  @version "3.3.1"
  @url_docs "https://hexdocs.pm/ex_aws_sqs"
  @url_github "https://github.com/ex-aws/ex_aws_sqs"

  def project do
    [
      app: :ex_aws_sqs,
      name: "ExAws.SQS",
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:test), do: [:logger, :hackney]
  defp extra_applications(_), do: [:logger]

  defp package do
    [
      description: "ExAws.SQS service package",
      maintainers: ["Ben Wilson"],
      files: ["lib", "mix.exs", "CHANGELOG.md", "README.md", "CONTRIBUTING.md"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@url_docs}/changelog.html",
        "GitHub" => @url_github
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:hackney, "~> 1.9", optional: true},
      {:jason, "~> 1.1", optional: true},
      {:saxy, "~> 1.1", optional: true},
      {:sweet_xml, ">= 0.0.0", optional: true},
      ex_aws()
    ]
  end

  defp docs do
    [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_url: @url_github,
      source_ref: "#v{@version}",
      formatters: ["html"]
    ]
  end

  defp ex_aws() do
    case System.get_env("AWS") do
      "LOCAL" -> {:ex_aws, path: "../ex_aws"}
      _ -> {:ex_aws, "~> 2.1"}
    end
  end
end
