defmodule Bytepack.Umbrella.MixProject do
  use Mix.Project

  def project() do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      releases: releases()
    ]
  end

  defp aliases() do
    [
      setup: ["cmd mix setup"]
    ]
  end

  defp releases() do
    [
      bytepack: [
        applications: [bytepack_web: :permanent]
      ]
    ]
  end
end
