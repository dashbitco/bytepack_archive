defmodule BytepackWeb.PackageLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.AuditLog, only: [system: 1]

  setup :register_and_login_user

  defp setup_package(context) do
    tarball = Bytepack.PackagesFixtures.hex_package_tarball("foo-1.0.0/foo-1.0.0.tar")

    {:ok, %{package: package, release: release}} =
      Bytepack.Hex.publish(system(context.org), context.org, tarball)

    %{package: package, release: release}
  end

  describe "Index" do
    setup :setup_package

    test "list packages", %{conn: conn, org: org, package: package} do
      {:ok, _, html} = live(conn, Routes.package_index_path(conn, :index, org))
      assert html =~ "Packages"
      assert html =~ package.name
    end
  end

  describe "Show" do
    setup :setup_package

    test "shows package", %{conn: conn, org: org, package: package} do
      {:ok, live, html} =
        live(conn, Routes.package_show_path(conn, :show, org, package.type, package.name))

      assert html =~ package.name
      assert html =~ "nimble_options"
      assert html =~ "~&gt; 0.1.0"
      assert html =~ "Edit"

      url = Routes.hex_test_repo_path(conn, :repo_index, org)
      refute html =~ url

      assert live
             |> element("#btn-testing-show", "Show instructions")
             |> render_click() =~ url

      refute html =~ "mix hex.publish package"

      assert live
             |> element("#btn-update-show", "Show instructions")
             |> render_click() =~ "mix hex.publish package"
    end

    test "updates package on broadcast", %{conn: conn, user: user, org: org, package: package} do
      {:ok, live, _html} =
        live(conn, Routes.package_show_path(conn, :show, org, package.type, package.name))

      {:ok, release} = Bytepack.Packages.create_release(package, 1024, %{version: "2.0.0"})
      Bytepack.Packages.broadcast_published(user.id, package, release, false)
      assert render(live) =~ "#{package.name} v2.0.0 was published successfully!"
    end

    test "switches between package versions", %{conn: conn, org: org, package: package} do
      tarball = Bytepack.PackagesFixtures.hex_package_tarball("foo-1.1.0/foo-1.1.0.tar")
      {:ok, _} = Bytepack.Hex.publish(system(org), org, tarball)

      {:ok, live, html} =
        live(conn, Routes.package_show_path(conn, :show, org, package.type, package.name))

      assert html =~ package.name
      assert html =~ "nimble_options"
      assert html =~ "~&gt; 0.2.0"
      assert html =~ ~s|v1.1.0 <span class="feather-icon icon-chevron-down"></span>|

      html =
        live
        |> element(".dropdown-item", "1.0.0")
        |> render_click()

      assert html =~ "nimble_options"
      assert html =~ "~&gt; 0.1.0"
      assert html =~ ~s|v1.0.0 <span class="feather-icon icon-chevron-down"></span>|
    end
  end

  describe "New" do
    test "new package instructions", %{conn: conn, org: org, user: user} = context do
      {:ok, live, html} = live(conn, Routes.package_new_path(conn, :new, org))
      assert html =~ "Step 1:"

      %{package: package, release: release} = setup_package(context)
      Bytepack.Packages.broadcast_published(user.id, package, release, true)

      assert_redirect(
        live,
        Routes.package_show_path(conn, :show, org, package.type, package.name)
      )
    end
  end

  describe "Edit" do
    setup :setup_package

    test "edits a package", %{conn: conn, org: org, package: package} do
      {:ok, edit_live, html} =
        live(conn, Routes.package_show_path(conn, :edit, org, package.type, package.name))

      assert html =~ "Edit package"

      new_description = "A new package description"
      new_external_doc = "https://localhost:4000/docs"

      form_params = [
        description: new_description,
        external_doc_url: new_external_doc
      ]

      {:ok, _, html} =
        edit_live
        |> form("#form-package", package: form_params)
        |> render_submit()
        |> follow_redirect(
          conn,
          Routes.package_show_path(conn, :show, org, package.type, package.name)
        )

      assert html =~ "Package updated successfully"
      assert html =~ new_description
      assert html =~ "External documentation"
      assert html =~ new_external_doc
    end
  end
end
