defmodule BytepackWeb.SaleLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.PackagesFixtures
  import Bytepack.SalesFixtures
  import Bytepack.SwooshHelpers

  setup :register_and_login_user

  describe "Index" do
    test "lists sales", %{conn: conn, org: org} do
      product1 = product_fixture(org)
      product2 = product_fixture(org)
      product3 = product_fixture(org)

      buyer_user = user_fixture()
      buyer_org = org_fixture(buyer_user)
      sale = sale_fixture(org, product1, email: buyer_user.email)
      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale, buyer_org)
      pending_email = unique_user_email()
      sale_fixture(org, product2, email: pending_email)

      {:ok, _, html} = live(conn, Routes.sale_index_path(conn, :index, org))
      assert html =~ product1.name
      assert html =~ buyer_org.name
      assert html =~ buyer_user.email
      assert html =~ product2.name
      assert html =~ pending_email
      assert html =~ "Pending"
      assert html =~ "Edit"
      refute html =~ product3.name
    end

    test "show empty page information when there are no sales or packages", %{
      conn: conn,
      org: org
    } do
      {:ok, _, html} = live(conn, Routes.sale_index_path(conn, :index, org))

      assert html =~ "You have not published any packages yet."
      assert html =~ "Add new package"
    end

    test "show empty page information when there are neither sales nor products, but a package",
         %{conn: conn, org: org} do
      package_fixture(org)
      {:ok, _, html} = live(conn, Routes.sale_index_path(conn, :index, org))

      assert html =~ "You have not recorded any products yet."
      assert html =~ "Add new product"
    end

    test "show empty page information when there are no sales but one product", %{
      conn: conn,
      org: org
    } do
      product_fixture(org)
      {:ok, _, html} = live(conn, Routes.sale_index_path(conn, :index, org))

      assert html =~ "You have not recorded any sales yet."
      assert html =~ "Add new sale"
      assert html =~ "Learn about sales webhooks"
    end
  end

  describe "New Sale" do
    test "create a sale", %{conn: conn, org: org} do
      product = product_fixture(org)

      {:ok, new_live, _} = live(conn, Routes.sale_index_path(conn, :new, org))

      external_id = "54321"
      pending_email = unique_user_email()

      form_params = [
        email: pending_email,
        product_id: product.id,
        external_id: external_id
      ]

      {:ok, _, html} =
        new_live
        |> form("#form-sale", sale: form_params)
        |> render_submit()
        |> follow_redirect(conn, Routes.sale_index_path(conn, :index, org))

      assert html =~ "Sale created successfully"
      assert html =~ product.name
      assert html =~ external_id
      assert html =~ pending_email
      assert html =~ "Pending"

      assert_received_email(
        to: pending_email,
        subject: "Access your #{product.name} purchase on Bytepack"
      )
    end

    test "redirects to index when there is neither products nor packages", %{conn: conn, org: org} do
      assert {:error, {:redirect, %{to: path}}} =
               live(conn, Routes.sale_index_path(conn, :new, org))

      assert path == Routes.sale_index_path(conn, :index, org)

      package_fixture(org)

      assert {:error, {:redirect, %{to: path}}} =
               live(conn, Routes.sale_index_path(conn, :new, org))

      assert path == Routes.sale_index_path(conn, :index, org)

      product_fixture(org)

      assert {:ok, _, html} = live(conn, Routes.sale_index_path(conn, :new, org))
      assert html =~ "New sale"
    end
  end

  describe "Edit Sale" do
    test "edit a sale", %{conn: conn, org: org} do
      product = product_fixture(org)
      second_product = product_fixture(org)
      sale = sale_fixture(org, product)
      refute sale.external_id

      {:ok, new_live, _} = live(conn, Routes.sale_index_path(conn, :index, org))

      new_live
      |> element("#sale-#{sale.id} a", "Edit")
      |> render_click()

      external_id = "31546123"

      form_params = [
        external_id: external_id,
        product_id: second_product.id
      ]

      {:ok, _, html} =
        new_live
        |> form("#form-sale", sale: form_params)
        |> render_submit()
        |> follow_redirect(conn, Routes.sale_index_path(conn, :index, org))

      assert html =~ "Sale updated successfully"
      assert html =~ second_product.name
      assert html =~ external_id
    end

    test "revoke a pending sale", %{conn: conn, org: org} do
      product = product_fixture(org)
      sale = sale_fixture(org, product)

      {:ok, new_live, html} = live(conn, Routes.sale_index_path(conn, :index, org))
      assert html =~ "Pending"

      new_live
      |> element("#sale-#{sale.id} a", "Revoke")
      |> render_click()

      {:ok, _, html} =
        new_live
        |> form("#form-sale-revoke", sale: [revoke_reason: "subscription cancelled"])
        |> render_submit()
        |> follow_redirect(conn, Routes.sale_index_path(conn, :index, org))

      assert html =~ "Sale revoked successfully"
      assert html =~ "Revoked"
      assert html =~ "Reason: subscription cancelled"

      sale = Bytepack.Repo.get!(Bytepack.Sales.Sale, sale.id)
      assert sale.revoked_at
      assert sale.revoke_reason == "subscription cancelled"
    end

    test "activate a revoked pending sale", %{conn: conn, org: org} do
      product = product_fixture(org)
      sale = revoked_sale_fixture(seller_fixture(org), product)

      {:ok, new_live, html} = live(conn, Routes.sale_index_path(conn, :index, org))
      assert html =~ "Revoked"

      html =
        new_live
        |> element("#sale-#{sale.id} button", "Reactivate")
        |> render_click()

      assert html =~ "Sale reactivated successfully"
      assert html =~ "Pending"

      refute Bytepack.Repo.get!(Bytepack.Sales.Sale, sale.id).revoked_at
    end

    test "delete a pending sale", %{conn: conn, org: org} do
      product = product_fixture(org)
      sale = sale_fixture(org, product)

      {:ok, new_live, html} = live(conn, Routes.sale_index_path(conn, :edit, org, sale))

      assert html =~ "Edit pending sale"
      assert html =~ "Delete"

      {:ok, _, html} =
        new_live
        |> element("#btn-delete-sale", "Delete")
        |> render_click()
        |> follow_redirect(conn, Routes.sale_index_path(conn, :index, org))

      assert html =~ "Sale deleted successfully"

      refute html =~ product.name
    end

    test "revoke a completed sale", %{conn: conn, org: org} do
      product = product_fixture(org)
      buyer_user = user_fixture()
      buyer_org = org_fixture(buyer_user)

      sale = sale_fixture(org, product, %{email: buyer_user.email})

      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale, buyer_org)

      {:ok, new_live, html} = live(conn, Routes.sale_index_path(conn, :index, org))
      assert html =~ "Active"

      new_live
      |> element("#sale-#{sale.id} a", "Revoke")
      |> render_click()

      {:ok, _, html} =
        new_live
        |> form("#form-sale-revoke", sale: [revoke_reason: "subscription cancelled"])
        |> render_submit()
        |> follow_redirect(conn, Routes.sale_index_path(conn, :index, org))

      assert html =~ "Sale revoked successfully"
      assert html =~ "Revoked"
      assert html =~ "Reason: subscription cancelled"

      sale = Bytepack.Repo.get!(Bytepack.Sales.Sale, sale.id)
      assert sale.revoked_at
      assert sale.revoke_reason == "subscription cancelled"
    end
  end
end
