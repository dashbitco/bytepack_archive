defmodule Bytepack.PackagesFixtures do
  def unique_package_name(), do: "package#{System.unique_integer([:positive])}"

  def package_fixture(org, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: unique_package_name(),
        type: "hex",
        description: "Lorem ipsum."
      })

    {:ok, package} = Bytepack.Packages.create_package(org, attrs)
    {:ok, _release} = Bytepack.Packages.create_release(package, 1024, %{version: "1.0.0"})
    package
  end

  def package_with_multiple_releases_fixture(org, attrs \\ %{}) do
    package = package_fixture(org, attrs)

    {:ok, _release} = Bytepack.Packages.create_release(package, 1024, %{version: "1.3.0"})
    {:ok, _release} = Bytepack.Packages.create_release(package, 1024, %{version: "1.1.0"})

    package
  end

  def hex_package_fixture(org, tarball_path, fun \\ :noop) do
    {:ok, %{package: package}} =
      Bytepack.Hex.publish(
        Bytepack.AuditLog.system(org),
        org,
        hex_package_tarball(tarball_path, fun)
      )

    package
  end

  @doc """
  Return a Hex tarball at the given `path`.

  An optional `fun` might be given to update the tarball
  (by unpacking, applying the function, and packing it again)
  before returning.
  """
  def hex_package_tarball(path, fun \\ :noop) do
    Path.expand(Path.join(["packages", path]), __DIR__)
    |> File.read!()
    |> update_hex_tarball(fun)
  end

  defp update_hex_tarball(tarball, :noop) do
    tarball
  end

  defp update_hex_tarball(tarball, fun) when is_function(fun, 1) do
    {:ok, result} = :hex_tarball.unpack(tarball, :memory)
    result = fun.(result)
    {:ok, result} = :hex_tarball.create(result.metadata, result.contents)
    result.tarball
  end
end
