defmodule BytepackWeb.HexSmokeTest do
  use BytepackWeb.ConnCase, only: true

  @moduletag :integration

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import ExUnit.CaptureIO

  setup do
    Application.put_env(:bytepack, :packages_store,
      api: Bytepack.Packages.Store.GCS,
      bucket: "bytepack-test-store"
    )

    on_exit(fn ->
      Application.put_env(:bytepack, :packages_store, api: Bytepack.Packages.Store.Local)
    end)

    credentials =
      "../../../../bytepack/test/support/fixtures/packages/storage-test-credentials.json"
      |> Path.expand(__DIR__)
      |> File.read!()
      |> Jason.decode!()

    start_supervised!(
      {Goth,
       name: Bytepack.Goth,
       credentials: credentials,
       http_client: {Goth.HTTPClient.Finch, name: Bytepack.Finch}}
    )

    user = user_fixture()
    org = org_fixture(user)
    membership = Bytepack.Repo.one!(Bytepack.Orgs.Membership)
    write_token = Bytepack.Orgs.Membership.encode_write_token(membership)
    read_token = Bytepack.Orgs.Membership.encode_read_token(membership)
    Bytepack.Hex.create_registry!(org)
    %{org: org, read_token: read_token, write_token: write_token}
  end

  test "publish", %{org: org, test: test, read_token: read_token, write_token: write_token} do
    tmp_dir = "tmp/#{test}"
    File.rm_rf!(tmp_dir)

    dir = "#{tmp_dir}/publish"
    File.mkdir_p!(dir)

    File.cd!(dir, fn ->
      File.write!("mix.exs", """
      defmodule Foo.MixProject do
        use Mix.Project

        def project() do
          [
            app: :foo,
            version: "1.0.0",
            description: "An example Hex package.",
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
      """)

      # make the tarball bigger
      File.mkdir_p!("priv")
      File.write!("priv/big.txt", String.duplicate("a", 67_000_000))

      assert capture_io(fn ->
               0 = Mix.shell().cmd("mix deps.get")
               0 = Mix.shell().cmd("mix hex.build")
             end) =~ "Saved to foo-1.0.0.tar"

      assert capture_io(fn ->
               0 =
                 Mix.shell().cmd(
                   "mix hex.publish package --yes",
                   env: [
                     {"HEX_API_URL", "http://localhost:4002/pkg/hex/#{org.slug}/api"},
                     {"HEX_API_KEY", write_token}
                   ]
                 )
             end) =~ "Package published to http://localhost:4002"
    end)

    dir = "#{tmp_dir}/deps.get"
    File.mkdir_p!(dir)

    File.cd!(dir, fn ->
      File.write!("mix.exs", """
      defmodule Bar.MixProject do
        use Mix.Project

        def project() do
          [
            app: :foo,
            version: "1.0.0",
            description: "An example Hex package.",
            deps: [
              {:foo, "~> 1.0", repo: #{org.slug |> String.to_atom() |> inspect()}},
            ]
          ]
        end
      end
      """)

      env = [
        {"HEX_HOME", "."}
      ]

      url = "http://localhost:4002/pkg/hex/#{org.slug}/test_repo"

      auth = "authorization:#{read_token}"
      0 = Mix.shell().cmd("curl --fail --silent -H #{auth} #{url}/public_key > public_key.pem")

      cmd =
        "mix hex.repo add #{org.slug} --public-key public_key.pem #{url} --auth-key=#{read_token}"

      0 = Mix.shell().cmd(cmd, env: env)

      assert capture_io(fn ->
               0 = Mix.shell().cmd("mix deps.get", env: env)
               0 = Mix.shell().cmd("mix compile")
             end) =~ "Dependency resolution completed"

      0 = Mix.shell().cmd("mix run -e 'true = Code.ensure_loaded?(NimbleOptions)'")
    end)
  after
    path = Bytepack.Hex.tarball_path(org.id, "foo", "1.0.0")
    Bytepack.Packages.Store.delete!(path)
  end
end
