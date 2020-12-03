defmodule Bytepack.ReleasesFixtures do
  alias Bytepack.Packages

  def unique_release_version do
    "1.0.#{System.unique_integer([:positive])}"
  end

  def release_fixture(package, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        version: unique_release_version()
      })

    size = System.unique_integer([:positive])
    {:ok, release} = Packages.create_release(package, size, attrs)
    release
  end
end
