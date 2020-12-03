defmodule Bytepack.PackagesTest do
  use Bytepack.DataCase, async: true

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.PackagesFixtures
  import Bytepack.ReleasesFixtures

  alias Bytepack.Orgs.Membership
  alias Bytepack.Packages
  alias Bytepack.Packages.PackageDownload

  setup do
    user = user_fixture()
    %{org: org_fixture(user), user: user}
  end

  describe "packages" do
    test "list_packages/1 returns all packages", %{org: org} do
      package = package_fixture(org)
      assert Packages.list_available_packages(org) == [package]
    end

    test "list_packages/2 returns all packages by type", %{org: org} do
      package = package_fixture(org)
      assert Packages.list_available_packages(org, type: "hex") == [package]
      assert Packages.list_available_packages(org, type: "other") == []
    end

    test "get_package_by!/2 returns the package with the given fields", %{org: org} do
      package = package_fixture(org)
      assert Packages.get_available_package_by!(org, id: package.id).id == package.id
    end

    test "create_package/2 with valid data creates a package", %{org: org} do
      params = %{type: "hex", name: "foo", description: "bar"}
      assert {:ok, package} = Packages.create_package(org, params)
      assert package.org_id == org.id
      assert package.name == "foo"
    end

    test "create_package/1 with invalid data returns error changeset", %{org: org} do
      assert {:error, changeset} = Packages.create_package(org, %{name: ""})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "create_package/1 with duplicated name returns error changeset", %{org: org} do
      params = %{type: "hex", name: "foo", description: "bar"}
      package_fixture(org, params)

      assert {:error, changeset} = Packages.create_package(org, params)
      assert "has already been taken" in errors_on(changeset).name
    end

    test "update_package/2 updates the description and external docs", %{org: org} do
      package =
        package_fixture(org, description: "Random package", external_doc_url: "http://foo")

      new_description = "Awesome package"
      external_doc_url = "https://foo.com/docs"

      assert {:ok, updated} =
               Packages.update_package(system(org), package, %{
                 description: new_description,
                 external_doc_url: external_doc_url
               })

      assert updated.description == new_description
      assert updated.external_doc_url == external_doc_url

      [audit_log] = Bytepack.AuditLog.list_by_org(org, action: "packages.update_package")
      assert audit_log.params["package_id"] == package.id
      assert audit_log.params["description"] == new_description
      assert audit_log.params["external_doc_url"] == external_doc_url
    end

    test "update_package/2 auto correct the external doc URL without the scheme", %{org: org} do
      package =
        package_fixture(org, description: "Random package", external_doc_url: "http://foo")

      assert {:ok, updated} =
               Packages.update_package(system(), package, %{
                 external_doc_url: "awesome-package.com/howto"
               })

      assert updated.external_doc_url == "https://awesome-package.com/howto"
    end

    test "update_package/2 returns errors with invalid data", %{org: org} do
      package =
        package_fixture(org, description: "Random package", external_doc_url: "http://foo")

      assert {:error, changeset} =
               Packages.update_package(system(), package, %{
                 description: "",
                 external_doc_url: "ftp://foo/bar.html"
               })

      assert "can't be blank" in errors_on(changeset).description
      assert "should be a HTTP or HTTPS link" in errors_on(changeset).external_doc_url
    end
  end

  describe "releases" do
    test "create_release/3 with invalid data", %{org: org} do
      {:error, changeset} = Packages.create_release(package_fixture(org), 54321, %{version: nil})

      assert "can't be blank" in errors_on(changeset).version

      {:error, changeset} =
        Packages.create_release(package_fixture(org), 54321, %{version: "zeta.alpha.beta"})

      assert "does not follow the Semantic Versioning 2.0 schema" in errors_on(changeset).version
    end

    test "preload_releases/1 sorts releases by version, in descending order", %{org: org} do
      package =
        org
        |> package_with_multiple_releases_fixture()
        |> Packages.preload_releases()

      assert Enum.map(package.releases, & &1.version) == ["1.3.0", "1.1.0", "1.0.0"]
    end
  end

  describe "increment_download_counter!/3" do
    test "increases the download counter for a release", %{org: org, user: user} do
      package = package_fixture(org)
      release = release_fixture(package)
      membership = %Membership{org_id: org.id, member_id: user.id}

      Packages.increment_download_counter!(release, membership, ~D[2020-08-06])

      assert download_count(org) == 1

      Packages.increment_download_counter!(release, membership, ~D[2020-08-07])
      Packages.increment_download_counter!(release, membership, ~D[2020-08-07])

      assert download_count(org) == 3

      original_size = release.size_in_bytes
      new_size = release.size_in_bytes + 5432

      release = Repo.update!(change(release, %{size_in_bytes: new_size}))
      Packages.increment_download_counter!(release, membership, ~D[2020-08-07])

      user_id = user.id
      org_id = org.id
      release_id = release.id

      assert [
               %PackageDownload{
                 size: ^original_size,
                 counter: 1,
                 date: ~D[2020-08-06],
                 org_id: ^org_id,
                 release_id: ^release_id,
                 user_id: ^user_id
               },
               %PackageDownload{
                 size: ^original_size,
                 counter: 2,
                 date: ~D[2020-08-07],
                 org_id: ^org_id,
                 release_id: ^release_id,
                 user_id: ^user_id
               },
               %PackageDownload{
                 size: ^new_size,
                 counter: 1,
                 date: ~D[2020-08-07],
                 org_id: ^org_id,
                 release_id: ^release_id,
                 user_id: ^user_id
               }
             ] = Repo.all(from(pd in PackageDownload, order_by: [asc: :date, desc: :counter]))
    end

    def download_count(org) do
      query =
        from(pd in PackageDownload,
          select: sum(pd.counter),
          where: pd.org_id == ^org.id,
          group_by: pd.org_id
        )

      Repo.one!(query)
    end
  end
end
