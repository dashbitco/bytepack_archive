defmodule Bytepack.HexReleasesFixtures do
  alias Bytepack.Hex
  alias Bytepack.Repo

  import Ecto.Changeset, only: [change: 2]

  def hex_release_fixture(release, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        inner_checksum: :crypto.strong_rand_bytes(16),
        outer_checksum: :crypto.strong_rand_bytes(16),
        deps: []
      })

    {:ok, release} = Repo.insert(change(%Hex.Release{release: release}, attrs))
    release
  end
end
