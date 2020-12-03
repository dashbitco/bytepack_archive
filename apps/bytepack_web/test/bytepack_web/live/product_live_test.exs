defmodule BytepackWeb.ProductLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.PackagesFixtures
  import Bytepack.SalesFixtures

  setup :register_and_login_user

  setup %{org: org, user: user} do
    foo = hex_package_fixture(org, "foo-1.0.0/foo-1.0.0.tar")

    bar =
      hex_package_fixture(org, "bar-1.0.0/bar-1.0.0.tar", fn r ->
        put_in(r.metadata["requirements"]["foo"]["repository"], org.slug)
      end)

    baz =
      hex_package_fixture(org, "baz-1.0.0/baz-1.0.0.tar", fn r ->
        put_in(r.metadata["requirements"]["bar"]["repository"], org.slug)
      end)

    %{foo: foo, bar: bar, baz: baz, user: user}
  end

  describe "Index" do
    test "lists products", %{conn: conn, org: org, foo: foo} do
      product1 = product_fixture(org, package_ids: [foo.id])
      product2 = product_fixture(org_fixture(user_fixture()))

      {:ok, _, html} = live(conn, Routes.product_index_path(conn, :index, org))
      assert html =~ product1.name
      refute html =~ product2.name

      assert html =~ foo.name
    end

    test "ensures only sellers can access products", %{conn: conn, org: org} do
      Ecto.Changeset.change(org, is_seller: false) |> Bytepack.Repo.update!()

      {:ok, _, html} =
        live(conn, Routes.product_index_path(conn, :index, org))
        |> follow_redirect(conn, Routes.dashboard_index_path(conn, :index))

      assert html =~ "Access denied"
    end

    test "show blank banner when there are no products and no packages", %{conn: conn, user: user} do
      org_without_packages = org_fixture(user)

      {:ok, _, html} = live(conn, Routes.product_index_path(conn, :index, org_without_packages))
      assert html =~ "You have not published any packages yet."
      assert html =~ "Add new package"
    end

    test "show blank banner when there are no products but with packages", %{conn: conn, org: org} do
      {:ok, _, html} = live(conn, Routes.product_index_path(conn, :index, org))
      assert html =~ "You have not added any products yet."
      assert html =~ "Add new product"
    end
  end

  describe "New" do
    test "renders new product form", %{conn: conn, org: org, foo: foo, bar: bar, baz: baz} do
      product_name = unique_product_name()

      {:ok, live, html} = live(conn, Routes.product_new_path(conn, :new, org))
      assert html =~ "New Product"
      assert html =~ foo.name
      assert html =~ bar.name
      assert html =~ baz.name

      refute has_element?(live, "#form-product_package_ids_#{foo.id}:checked")
      refute has_element?(live, "#form-product_package_ids_#{bar.id}:checked")
      refute has_element?(live, "#form-product_package_ids_#{baz.id}:checked")

      html =
        live
        |> element("#form-product")
        |> render_change(%{
          product: %{
            name: product_name,
            description: "Lorem ipsum.",
            url: "https://acme.com",
            custom_instructions: "one two **strong** <em>em</em>",
            package_ids: [baz.id]
          }
        })

      assert html =~ "one two <strong>strong</strong>"
      assert html =~ ~s|<div class="markdown-preview"|
      refute html =~ ~s|<em>em</em>|

      assert has_element?(live, "#form-product_package_ids_#{foo.id}:checked")
      assert has_element?(live, "#form-product_package_ids_#{bar.id}:checked")
      assert has_element?(live, "#form-product_package_ids_#{baz.id}:checked")

      live
      |> element("#form-product")
      |> render_change(%{product: %{package_ids: [bar.id]}})

      assert has_element?(live, "#form-product_package_ids_#{foo.id}:checked")
      assert has_element?(live, "#form-product_package_ids_#{bar.id}:checked")
      refute has_element?(live, "#form-product_package_ids_#{baz.id}:checked")

      {:ok, _, html} =
        live
        |> form("#form-product")
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Product created successfully"
      assert html =~ product_name
      assert html =~ foo.name
      assert html =~ bar.name
      refute html =~ baz.name
    end

    test "redirects to index when there is no packages", %{conn: conn, user: user} do
      org_without_packages = org_fixture(user)

      assert {:error, {:redirect, %{to: path}}} =
               live(conn, Routes.product_new_path(conn, :new, org_without_packages))

      assert path == Routes.product_index_path(conn, :index, org_without_packages)

      package_fixture(org_without_packages)

      assert {:ok, _, html} =
               live(conn, Routes.product_new_path(conn, :new, org_without_packages))

      assert html =~ "New Product"
    end
  end

  describe "Edit" do
    test "renders unsold product form", %{conn: conn, org: org, foo: foo, bar: bar, baz: baz} do
      product = product_fixture(org, package_ids: [foo.id])

      {:ok, live, _html} = live(conn, Routes.product_edit_path(conn, :edit, org, product.id))

      assert has_element?(live, "#form-product_package_ids_#{foo.id}:checked")
      refute has_element?(live, "#form-product_package_ids_#{bar.id}:checked")
      refute has_element?(live, "#form-product_package_ids_#{baz.id}:checked")

      html =
        live
        |> element("#form-product")
        |> render_change(%{
          product: %{
            name: "Updated name",
            custom_instructions: "one two *em* <strong>strong</strong>",
            package_ids: [baz.id]
          }
        })

      assert html =~ "one two <em>em</em>"
      assert html =~ ~s|<div class="markdown-preview"|
      refute html =~ ~s|<strong>strong</strong>|

      assert has_element?(live, "#form-product_package_ids_#{foo.id}:checked")
      assert has_element?(live, "#form-product_package_ids_#{bar.id}:checked")
      assert has_element?(live, "#form-product_package_ids_#{baz.id}:checked")
      refute html =~ "Note:"
    end

    test "renders sold product form", %{conn: conn, org: org, foo: foo, bar: bar, baz: baz} do
      product = product_fixture(org, package_ids: [foo.id])
      sale_fixture(org, product, email: "alice@example.com")

      {:ok, live, html} = live(conn, Routes.product_edit_path(conn, :edit, org, product.id))
      assert html =~ "Note: This product already has sales"

      assert has_element?(live, "#form-product_package_ids_#{foo.id}[disabled=disabled]:checked")
      assert has_element?(live, "input[type=hidden][value=#{foo.id}]")
      refute has_element?(live, "#form-product_package_ids_#{bar.id}:checked")
      refute has_element?(live, "#form-product_package_ids_#{baz.id}:checked")

      # Updating only the name does not uncheck packages
      {:error, {:live_redirect, _}} =
        live
        |> element("#form-product")
        |> render_submit(%{
          product: %{
            name: "Updated name without packages"
          }
        })

      {:ok, live, _html} = live(conn, Routes.product_edit_path(conn, :edit, org, product.id))
      assert has_element?(live, "#form-product_package_ids_#{foo.id}[disabled=disabled]:checked")
      assert has_element?(live, "input[type=hidden][value=#{foo.id}]")
      refute has_element?(live, "#form-product_package_ids_#{bar.id}:checked")
      refute has_element?(live, "#form-product_package_ids_#{baz.id}:checked")

      # Updating name with packages changes only relevant packages
      {:error, {:live_redirect, _}} =
        live
        |> element("#form-product")
        |> render_submit(%{
          product: %{
            name: "Updated name with packages",
            package_ids: [bar.id]
          }
        })

      {:ok, live, _html} = live(conn, Routes.product_edit_path(conn, :edit, org, product.id))
      assert has_element?(live, "#form-product_package_ids_#{foo.id}[disabled=disabled]::checked")
      assert has_element?(live, "input[type=hidden][value=#{foo.id}]")
      assert has_element?(live, "#form-product_package_ids_#{bar.id}[disabled=disabled]::checked")
      assert has_element?(live, "input[type=hidden][value=#{bar.id}]")
      refute has_element?(live, "#form-product_package_ids_#{baz.id}:checked")
    end
  end
end
