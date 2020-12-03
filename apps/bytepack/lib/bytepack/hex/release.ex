defmodule Bytepack.Hex.Release do
  use Bytepack.Schema
  import Ecto.Query
  alias Bytepack.Packages.{Package, Release}

  schema "hex_releases" do
    field :inner_checksum, :binary
    field :outer_checksum, :binary

    embeds_many :deps, Dep, primary_key: false do
      field :package, :string
      field :app, :string
      field :optional, :boolean
      field :repository, :string
      field :requirement, :string
    end

    belongs_to :release, Release

    timestamps()
  end

  def by_package(%Package{} = package) do
    from(r in __MODULE__,
      join: rr in assoc(r, :release),
      where: rr.package_id == ^package.id,
      preload: [release: rr]
    )
  end

  def by_release(%Release{} = release) do
    from(__MODULE__, where: [release_id: ^release.id])
  end
end
