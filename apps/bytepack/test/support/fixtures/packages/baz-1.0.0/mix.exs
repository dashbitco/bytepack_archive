# when changing this file, re-run `mix hex.build` in this directory.
defmodule Baz.MixProject do
  use Mix.Project

  def project() do
    [
      app: :baz,
      version: "1.0.0",
      description: """
      An example Hex package.

      Lorem ipsum.
      """,
      package: [
        licenses: ["Apache-2.0"],
        links: %{}
      ],
      deps: [
        {:bar, "~> 1.0", repo: "acme"}
      ]
    ]
  end
end
