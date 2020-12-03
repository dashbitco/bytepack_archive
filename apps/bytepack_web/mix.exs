defmodule BytepackWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :bytepack_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
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
      mod: {BytepackWeb.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
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
      {:phoenix, "~> 1.5.2"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_view, "~> 0.15.0"},
      {:phoenix_live_reload, "~> 1.2.4", only: :dev},
      {:phoenix_live_dashboard, "~> 0.4"},
      {:ecto_psql_extras, "~> 0.3"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.11"},
      {:bytepack, in_umbrella: true},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.2"},
      {:floki, ">= 0.0.0", only: :test},
      {:eqrcode, "~> 0.1.7"},
      {:sentry, "~> 8.0"},
      {:cmark, "~> 0.9.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd npm install --prefix assets"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
