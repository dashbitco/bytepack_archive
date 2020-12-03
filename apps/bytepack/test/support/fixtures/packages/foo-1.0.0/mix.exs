# when changing this file, re-run `mix hex.build` in this directory.
defmodule Foo.MixProject do
  use Mix.Project

  def project() do
    [
      app: :foo,
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
        {:nimble_options, "~> 0.1.0"}
      ]
    ]
  end
end
