defmodule BytepackWeb.HexControllerTest do
  use BytepackWeb.ConnCase

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.PackagesFixtures
  import Bytepack.SalesFixtures

  import Ecto.Query, only: [from: 2]

  setup do
    user = user_fixture()
    org = org_fixture(user)
    registry = Bytepack.Hex.create_registry!(org)
    membership = Bytepack.Repo.one!(Bytepack.Orgs.Membership)
    write_token = Bytepack.Orgs.Membership.encode_write_token(membership)
    read_token = Bytepack.Orgs.Membership.encode_read_token(membership)

    hex_config = %{
      :hex_core.default_config()
      | api_url: "http://localhost:4002/pkg/hex/#{org.slug}/api",
        api_key: write_token,
        repo_name: org.slug,
        repo_url: "http://localhost:4002/pkg/hex/#{org.slug}/test_repo",
        repo_key: read_token,
        repo_public_key: registry.public_key
    }

    # Let's also create a package that belongs elsewhere
    # and everything should still work.
    package_fixture(org, type: "npm")

    File.rm_rf!(Bytepack.Extensions.Plug.DevStore.dir())
    %{org: org, user: user, hex_config: hex_config}
  end

  test "publish with valid data", %{org: org, user: user, hex_config: hex_config} do
    Phoenix.PubSub.subscribe(Bytepack.PubSub, "user:#{user.id}:package:new")

    tarball = hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")
    {:ok, result} = :hex_tarball.unpack(tarball, :memory)

    assert {:ok, {200, _, _}} = :hex_api_release.publish(hex_config, tarball)

    assert_received {:published, data}
    assert data.version == "1.0.0"

    assert {:ok, {200, _, packages}} = :hex_repo.get_names(hex_config)
    assert packages == [%{name: "foo"}]

    assert {:ok, {200, _, packages}} = :hex_repo.get_versions(hex_config)
    assert packages == [%{name: "foo", retired: [], versions: ["1.0.0"]}]

    assert {:ok, {200, _, ^tarball}} = :hex_repo.get_tarball(hex_config, "foo", "1.0.0")
    assert {:ok, {200, _, ^tarball}} = :hex_repo.get_tarball(hex_config, "foo", "1.0.0")

    assert {:ok, {200, _, releases}} = :hex_repo.get_package(hex_config, "foo")

    [release] = releases
    assert release.version == "1.0.0"
    assert release.inner_checksum == result.inner_checksum
    assert release.outer_checksum == result.outer_checksum

    assert release.dependencies == [
             %{
               app: "nimble_options",
               package: "nimble_options",
               optional: false,
               repository: "hexpm",
               requirement: "~> 0.1.0"
             }
           ]

    package_downloads =
      Bytepack.Repo.one!(
        from(pd in Bytepack.Packages.PackageDownload,
          join: rl in Bytepack.Packages.Release,
          on: pd.release_id == rl.id,
          where: pd.org_id == ^org.id and rl.package_id == ^data.package_id
        )
      )

    size = byte_size(tarball)
    assert %Bytepack.Packages.PackageDownload{size: ^size, counter: 2} = package_downloads

    [log] = Bytepack.AuditLog.list_by_org(org, action: "packages.publish_package")
    assert log.params == %{"package_id" => data.package_id, "release_version" => "1.0.0"}
  end

  test "access buyer repo", %{org: seller_org, hex_config: hex_config} do
    tarball = hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")
    assert {:ok, {200, _, _}} = :hex_api_release.publish(hex_config, tarball)

    buyer_user = user_fixture()
    buyer_org = org_fixture(buyer_user)
    membership = Bytepack.Orgs.get_membership!(buyer_user, buyer_org.slug)
    read_token = Bytepack.Orgs.Membership.encode_read_token(membership)
    registry = Bytepack.Hex.create_registry!(buyer_org)

    hex_config = %{
      :hex_core.default_config()
      | repo_name: buyer_org.slug,
        repo_url: "http://localhost:4002/pkg/hex/#{buyer_org.slug}/repo",
        repo_key: read_token,
        repo_public_key: registry.public_key
    }

    assert {:ok, {200, _, []}} = :hex_repo.get_names(hex_config)
    assert {:ok, {200, _, []}} = :hex_repo.get_versions(hex_config)
    assert {:ok, {404, _, _}} = :hex_repo.get_package(hex_config, "foo")
    assert {:ok, {404, _, _}} = :hex_repo.get_tarball(hex_config, "foo", "1.0.0")

    foo_package = Bytepack.Packages.get_available_package_by!(seller_org, name: "foo")

    foo_product =
      product_fixture(
        seller_org,
        %{
          name: "Acme Foo",
          description: "Lorem ipsum.",
          package_ids: [foo_package.id]
        }
      )

    sale = sale_fixture(seller_org, foo_product, email: buyer_user.email)
    Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale, buyer_org)

    assert {:ok, {200, _, packages}} = :hex_repo.get_names(hex_config)
    assert packages == [%{name: "foo"}]

    assert {:ok, {200, _, packages}} = :hex_repo.get_versions(hex_config)
    assert packages == [%{name: "foo", retired: [], versions: ["1.0.0"]}]

    assert {:ok, {200, _, _}} = :hex_repo.get_tarball(hex_config, "foo", "1.0.0")

    assert {:ok, {200, _, releases}} = :hex_repo.get_package(hex_config, "foo")
    [release] = releases
    assert release.version == "1.0.0"
  end

  test "internal dependencies", %{hex_config: hex_config, org: org} do
    tarball =
      hex_package_tarball("bar-1.0.0/bar-1.0.0.tar", fn r ->
        update_in(
          r,
          [:metadata, "requirements", "foo"],
          &Map.replace!(&1, "repository", org.slug)
        )
      end)

    assert {:ok, {200, _, _}} = :hex_api_release.publish(hex_config, tarball)
    assert {:ok, {200, _, [release]}} = :hex_repo.get_package(hex_config, "bar")

    assert release.dependencies == [
             %{
               app: "foo",
               package: "foo",
               optional: false,
               requirement: "~> 1.0"
             },
             %{
               app: "nimble_options",
               package: "nimble_options",
               optional: false,
               repository: "hexpm",
               requirement: "~> 0.1.0"
             }
           ]
  end

  test "external dependencies", %{hex_config: hex_config} do
    external_org = org_fixture(user_fixture())

    tarball =
      hex_package_tarball("bar-1.0.0/bar-1.0.0.tar", fn r ->
        update_in(
          r,
          [:metadata, "requirements", "foo"],
          &Map.replace!(&1, "repository", external_org.slug)
        )
      end)

    assert {:ok, {500, _, _}} = :hex_api_release.publish(hex_config, tarball)
  end

  test "authentication", %{hex_config: hex_config} do
    tarball = hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")

    assert {:ok, {200, _, _}} = :hex_api_release.publish(hex_config, tarball)
    assert {:ok, {200, _, _}} = :hex_repo.get_tarball(hex_config, "foo", "1.0.0")

    assert {:ok, {401, _, _}} = :hex_api_release.publish(%{hex_config | api_key: "bad"}, tarball)

    assert {:ok, {401, _, _}} =
             :hex_repo.get_tarball(%{hex_config | repo_key: "bad"}, "foo", "1.0.0")
  end

  test "requires sellers for API access", %{hex_config: hex_config, org: org} do
    tarball = hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")
    Bytepack.Repo.update!(Ecto.Changeset.change(org, is_seller: false))
    assert {:ok, {401, _, _}} = :hex_api_release.publish(hex_config, tarball)
  end

  test "replace release", %{hex_config: hex_config} do
    tarball = hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")

    assert {:ok, {200, _, body}} = :hex_api_release.publish(hex_config, tarball)
    assert body == %{"html_url" => "http://localhost:4002"}

    assert {:ok, {422, _, body}} = :hex_api_release.publish(hex_config, tarball)
    assert %{"errors" => %{"inserted_at" => message}} = body
    assert message =~ "must include `--replace` flag"

    tarball =
      hex_package_tarball("foo-1.0.0/foo-1.0.0.tar", fn r ->
        r
        |> put_in([:metadata, "description"], "UPDATED")
        |> put_in([:metadata, "requirements", "nimble_options", "requirement"], "~> 0.2.0")
      end)

    assert {:ok, {200, _, body}} = :hex_api_release.publish(hex_config, tarball, replace: true)
    assert body == %{"html_url" => "http://localhost:4002"}
  end

  test "publish with invalid data", %{hex_config: hex_config} do
    metadata = %{name: "$$$", version: "1.0.0", description: "lorem ipsum"}
    {:ok, %{tarball: tarball}} = :hex_tarball.create(metadata, [])
    assert {:ok, {422, _, body}} = :hex_api_release.publish(hex_config, tarball)
    assert {"name", "has invalid format"} in body["errors"]

    metadata = %{name: "foo", version: "1.0.bad", description: "lorem ipsum"}
    {:ok, %{tarball: tarball}} = :hex_tarball.create(metadata, [])
    assert {:ok, {422, _, body}} = :hex_api_release.publish(hex_config, tarball)
    assert {"version", "does not follow the Semantic Versioning 2.0 schema"} in body["errors"]
  end

  test "publish bad tarball", %{hex_config: hex_config} do
    assert {:ok, {422, _, body}} = :hex_api_release.publish(hex_config, "bad")
    assert %{"errors" => %{"tar" => _}} = body
  end

  test "publish with store error", %{hex_config: hex_config} do
    metadata = %{name: "error", version: "1.0.0", description: "Lorem ipsum."}
    {:ok, %{tarball: tarball}} = :hex_tarball.create(metadata, [])

    assert {:ok, {500, _, _}} = :hex_api_release.publish(hex_config, tarball)
  end

  test "access non-existing registry" do
    hex_config = %{:hex_core.default_config() | repo_url: "http://localhost:4002/pkg/hex/bad"}
    assert {:ok, {404, _, _}} = :hex_repo.get_names(hex_config)
    assert {:ok, {404, _, _}} = :hex_repo.get_versions(hex_config)
    assert {:ok, {404, _, _}} = :hex_repo.get_package(hex_config, "bad")
    assert {:ok, {404, _, _}} = :hex_repo.get_tarball(hex_config, "bad", "1.0.0")
  end

  test "access non-existing package", %{hex_config: hex_config} do
    assert {:ok, {404, _, _}} = :hex_repo.get_package(hex_config, "bad")
    assert {:ok, {404, _, _}} = :hex_repo.get_tarball(hex_config, "bad", "1.0.0")
  end

  test "access non-existing release", %{hex_config: hex_config} do
    tarball = hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")
    assert {:ok, {200, _, _}} = :hex_api_release.publish(hex_config, tarball)

    assert {:ok, {404, _, _}} = :hex_repo.get_tarball(hex_config, "foo", "9.9.9")
  end

  test "access package with cache", %{hex_config: hex_config} do
    tarball = hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")

    assert {:ok, {200, _, _}} = :hex_api_release.publish(hex_config, tarball)
    assert {:ok, {200, headers, _releases}} = :hex_repo.get_package(hex_config, "foo")

    assert {:ok, {304, _, ""}} =
             :hex_repo.get_package(%{hex_config | http_etag: headers["etag"]}, "foo")
  end

  test "access tarball with cache", %{hex_config: hex_config} do
    tarball = hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")

    assert {:ok, {200, _, _}} = :hex_api_release.publish(hex_config, tarball)

    assert {:ok, {200, headers, ^tarball}} = :hex_repo.get_tarball(hex_config, "foo", "1.0.0")

    assert {:ok, {304, _, ""}} =
             :hex_repo.get_tarball(%{hex_config | http_etag: headers["etag"]}, "foo", "1.0.0")
  end

  test "public key", %{hex_config: hex_config} do
    conn =
      build_conn()
      |> put_req_header("authorization", hex_config.repo_key)
      |> get(hex_config.repo_url <> "/public_key")

    assert conn.status == 200
    assert conn.resp_body == hex_config.repo_public_key
  end
end
