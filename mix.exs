defmodule AccessGrid.MixProject do
  use Mix.Project

  def project do
    [
      app: :accessgrid,
      name: "AccessGrid",
      description: "An Elixir client for the AccessGrid API",
      version: "0.2.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      source_url: "https://github.com/Access-Grid/accessgrid-ex",
      homepage_url: "https://accessgrid.com/docs",
      start_permanent: Mix.env() == :prod
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Access-Grid/accessgrid-ex",
        "AccessGrid API Docs" => "https://accessgrid.com/docs"
      }
    ]
  end

  defp docs do
    [
      main: "AccessGrid",
      extras: [
        "guides/testing.md",
        "LICENSE"
      ],
      groups_for_modules: [
        "API Resources": [
          AccessGrid.Console,
          AccessGrid.AccessPasses
        ],
        Structs: [
          AccessGrid.AccessPass,
          AccessGrid.CardTemplate,
          AccessGrid.CardTemplate.PublishResult,
          AccessGrid.CardTemplate.Result,
          AccessGrid.CardTemplate.Summary,
          AccessGrid.CardTemplatePair,
          AccessGrid.CardTemplatePair.Summary,
          AccessGrid.CredentialProfile,
          AccessGrid.Event,
          AccessGrid.HidOrg,
          AccessGrid.IosPreflight,
          AccessGrid.LandingPage,
          AccessGrid.LedgerItem,
          AccessGrid.LedgerItem.AccessPass,
          AccessGrid.LedgerItem.CardTemplate,
          AccessGrid.SmartTapReveal,
          AccessGrid.Webhook
        ],
        Core: [
          AccessGrid.Client,
          AccessGrid.Types
        ],
        Utilities: [
          AccessGrid.Params,
          AccessGrid.Utils
        ],
        HTTP: [
          AccessGrid.HttpClient,
          AccessGrid.HttpClient.Behaviour,
          AccessGrid.HttpClient.Req,
          AccessGrid.HttpFailure,
          AccessGrid.HttpResponse
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", runtime: false, only: [:dev, :test]},
      {:dialyxir, "~> 1.4", runtime: false, only: [:dev, :test]},
      {:doctor, "~> 0.22", runtime: false, only: [:dev, :test]},
      {:ex_doc, "~> 0.40", runtime: false, only: :dev},
      {:gestalt, "~> 2.0"},
      {:mix_audit, "~> 2.1", runtime: false, only: [:dev, :test]},
      {:mix_test_interactive, "~> 5.1", runtime: false, only: [:dev, :test]},
      {:mox, "~> 1.2", only: :test},
      # Required by Req.Test for HTTP stubbing in tests.
      {:plug, "~> 1.14", only: :test},
      {:req, "~> 0.5.17"}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix],
      plt_add_deps: :app_tree,
      plt_core_path: "_build/plts/#{Mix.env()}",
      plt_local_path: "_build/plts/#{Mix.env()}"
    ]
  end
end
