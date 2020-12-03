defmodule Bytepack.MixProject do
  use Mix.Project

  def project do
    [
      app: :bytepack,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Bytepack.Application, []},
      extra_applications: [:logger, :runtime_tools]
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
      {:bcrypt_elixir, "~> 2.0"},
      # TODO: Remove override once goth is updated to latest finch
      {:finch, "~> 0.4.0", override: true},
      {:goth, github: "wojtekmach/goth"},
      {:nimble_totp, "~> 0.1"},
      {:plug_crypto, "~> 1.1"},
      {:phoenix_pubsub, "~> 2.0"},
      {:ecto_sql, "~> 3.4.4"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.0"},
      {:swoosh, "~> 1.0"},
      {:hex_core, "~> 0.7.0"},
      {:libcluster, "~> 3.2"},
      {:cmark, "~> 0.9.0"},
      {:plug_cowboy, "~> 2.0"},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 0.5", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
