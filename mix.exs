defmodule UiWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :ui_web,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {UiWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix Framework 1.8.1 (stable)
      {:phoenix, "~> 1.8.1"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      
      # Ecto for changesets (validation)
      {:ecto, "~> 3.11", optional: true},

      # Assets (dev only)
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},

      # Authentication
      {:guardian, "~> 2.3"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_oidc, "~> 0.1"},
      {:jose, "~> 1.11"},

      # HTTP Client (using :req as per project guidelines)
      {:req, "~> 0.4"},
      # Retained for SSE streaming (low-level)
      {:mint, "~> 1.5"},

      # Telemetry
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},

      # JSON & Utilities
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.2.0"},
      
      # Property-based testing
      {:stream_data, "~> 0.6", only: :test},

      # HTML Parser for URL previews
      {:floki, "~> 0.35"},

      # NATS client for real-time updates
      {:gnat, "~> 1.8"},

      # Caching for health checks and rate limiting
      {:cachex, "~> 3.6"},

      # Syntax highlighting for code preview
      {:makeup, "~> 1.1"},
      {:makeup_json, "~> 0.1"},

      # HTTP Server
      {:bandit, "~> 1.5"},
      
      # Mock Gateway for tests
      {:plug_cowboy, "~> 2.7", only: [:dev, :test]},

      # Test dependencies
      {:lazy_html, ">= 0.1.0", only: :test},
      {:meck, "~> 0.9", only: :test},

      # Test coverage
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind ui_web", "esbuild ui_web"],
      "assets.deploy": ["tailwind ui_web --minify", "esbuild ui_web --minify", "phx.digest"],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"],
      # Test aliases
      "test.all": ["mock.reset", "test"],
      # Coverage aliases
      "test.coverage": ["coveralls.html"],
      "test.coverage.detail": ["coveralls.detail"],
      "test.coverage.json": ["coveralls.json"]
    ]
  end
end
