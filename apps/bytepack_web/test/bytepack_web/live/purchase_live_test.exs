defmodule BytepackWeb.PurchaseLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.PackagesFixtures
  import Bytepack.SalesFixtures

  setup :register_and_login_user

  describe "Index" do
    test "lists purchases", %{conn: conn, org: org, user: user} do
      seller_org = org_fixture(user_fixture())
      product1 = product_fixture(seller_org)
      product2 = product_fixture(seller_org)

      sale = sale_fixture(seller_org, product1, email: user.email)
      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale, org)

      {:ok, _, html} = live(conn, Routes.purchase_index_path(conn, :index, org))
      assert html =~ product1.name
      refute html =~ product2.name
    end

    test "shows information when there are no purchases", %{conn: conn, org: org} do
      {:ok, _, html} = live(conn, Routes.purchase_index_path(conn, :index, org))
      assert html =~ "You have not made any purchases yet."
    end

    test "lists revoked purchases in a separate section", %{conn: conn, org: org, user: user} do
      seller_org = org_fixture(user_fixture())
      product1 = product_fixture(seller_org)
      product2 = product_fixture(seller_org)

      sale1 = sale_fixture(seller_org, product1, email: user.email)
      sale2 = sale_fixture(seller_org, product2, email: user.email)

      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale1, org)
      Bytepack.Sales.revoke_sale(Bytepack.AuditLog.system(), sale1, %{revoke_reason: "unpaid"})
      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale2, org)

      {:ok, view, _html} = live(conn, Routes.purchase_index_path(conn, :index, org))

      revoked_html = element(view, ".purchases__revoked") |> render()
      active_html = element(view, ".purchases__active") |> render()

      assert revoked_html =~ product1.name
      assert active_html =~ product2.name
    end
  end

  describe "Show" do
    test "show purchase with selected package details", %{conn: conn, org: org, user: user} do
      seller_org = org_fixture(user_fixture(), slug: "acme")

      package1 = hex_package_fixture(seller_org, "foo-1.0.0/foo-1.0.0.tar")
      package2 = hex_package_fixture(seller_org, "bar-1.0.0/bar-1.0.0.tar")
      product1 = product_fixture(seller_org, package_ids: [package1.id, package2.id])
      package3 = package_fixture(seller_org)
      product_fixture(seller_org, packag_ids: [package3.id])

      sale = sale_fixture(seller_org, product1, email: user.email)
      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale, org)

      {:ok, show_live, html} = live(conn, Routes.purchase_show_path(conn, :show, org, sale))
      assert html =~ package1.name
      assert html =~ package2.name
      refute html =~ package3.name

      assert html =~ ~s|<h5 class=\"my-1\">#{package1.name}</h5>|

      assert html =~
               ~s|{:#{package1.name}, &quot;&gt;= 0.0.0&quot;, repo: &quot;#{org.slug}&quot;}|

      html =
        show_live
        |> element("a", package2.name)
        |> render_click()

      assert html =~ ~s|<h5 class=\"my-1\">#{package2.name}</h5>|

      assert html =~
               ~s|{:#{package2.name}, &quot;&gt;= 0.0.0&quot;, repo: &quot;#{org.slug}&quot;}|

      refute html =~ "Edit"
    end

    test "show information about revoked puchase", %{conn: conn, org: org, user: user} do
      seller_org = org_fixture(user_fixture(), slug: "acme")
      package = hex_package_fixture(seller_org, "foo-1.0.0/foo-1.0.0.tar")
      product = product_fixture(seller_org, package_ids: [package.id])

      sale = sale_fixture(seller_org, product, email: user.email)
      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale, org)
      Bytepack.Sales.revoke_sale(Bytepack.AuditLog.system(), sale, %{revoke_reason: "unpaid"})

      {:ok, _show_live, html} = live(conn, Routes.purchase_show_path(conn, :show, org, sale))

      assert html =~ "This purchase has expired"
    end

    test "switches between package versions", %{conn: conn, org: org, user: user} do
      seller_org = org_fixture(user_fixture(), slug: "acme")
      package1 = hex_package_fixture(seller_org, "foo-1.0.0/foo-1.0.0.tar")
      package2 = hex_package_fixture(seller_org, "foo-1.1.0/foo-1.1.0.tar")
      product1 = product_fixture(seller_org, package_ids: [package1.id, package2.id])

      sale = sale_fixture(seller_org, product1, email: user.email)
      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale, org)

      {:ok, show_live, html} = live(conn, Routes.purchase_show_path(conn, :show, org, sale))

      assert html =~ ~s|v1.1.0 <span class="feather-icon icon-chevron-down"></span>|

      html =
        show_live
        |> element(".dropdown-item", "1.0.0")
        |> render_click()

      assert html =~ ~s|v1.0.0 <span class="feather-icon icon-chevron-down"></span>|
    end
  end
end
