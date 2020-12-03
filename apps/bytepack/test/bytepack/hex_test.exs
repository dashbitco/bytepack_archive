defmodule Bytepack.HexTest do
  use Bytepack.DataCase, async: true

  alias Bytepack.Hex

  import Bytepack.OrgsFixtures
  import Bytepack.AccountsFixtures
  import Bytepack.PackagesFixtures
  import Bytepack.ReleasesFixtures
  import Bytepack.HexReleasesFixtures

  describe "get_tarball_request/2" do
    test "returns a request" do
      acme = org_fixture(user_fixture())
      package = package_fixture(acme)

      request = Hex.get_tarball_request(package, "1.0.0")
      assert request.method == "GET"
      assert Path.basename(request.path) == "#{package.name}-1.0.0.tar"
    end
  end

  describe "get_hex_release!/2" do
    test "returns an existing Hex release" do
      acme = org_fixture(user_fixture())
      package = package_fixture(acme)
      release = release_fixture(package, %{version: "1.2.5"})
      hex_release = hex_release_fixture(release)

      assert %Bytepack.Hex.Release{id: id, outer_checksum: checksum, release: package_release} =
               Hex.get_hex_release!(package, "1.2.5")

      assert id == hex_release.id
      assert checksum == hex_release.outer_checksum
      assert %Bytepack.Packages.Release{} = package_release
      assert package_release.id == release.id
    end

    test "fails with inexisting Hex release" do
      acme = org_fixture(user_fixture())
      package = package_fixture(acme)

      assert_raise(Ecto.NoResultsError, fn ->
        Hex.get_hex_release!(package, "9.9.9")
      end)
    end
  end

  test "deps_map/1" do
    org = org_fixture(user_fixture(), slug: "acme")
    foo = hex_package_fixture(org, "foo-1.0.0/foo-1.0.0.tar")
    bar = hex_package_fixture(org, "bar-1.0.0/bar-1.0.0.tar")
    baz = hex_package_fixture(org, "baz-1.0.0/baz-1.0.0.tar")

    assert Hex.deps_map([foo, bar, baz]) == %{
             bar.id => MapSet.new([foo.id]),
             baz.id => MapSet.new([bar.id])
           }
  end
end
