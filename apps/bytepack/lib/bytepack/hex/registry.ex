defmodule Bytepack.Hex.Registry do
  use Bytepack.Schema

  schema "hex_registries" do
    field :public_key, :string
    field :private_key, :string

    belongs_to :org, Bytepack.Orgs.Org

    timestamps()
  end
end
