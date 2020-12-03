defmodule BytepackWeb.Onboarding.PurchaseLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.PackagesFixtures
  import Bytepack.SalesFixtures
  alias Bytepack.Purchases
  alias Bytepack.Sales

  setup do
    seller_org = org_fixture(user_fixture())
    package = hex_package_fixture(seller_org, "foo-1.0.0/foo-1.0.0.tar")
    product = product_fixture(seller_org, package_ids: [package.id])
    sale = sale_fixture(seller_org, product)
    %{sale: sale}
  end

  describe "Claim" do
    test "registers sale as unauthorized user", %{conn: conn, sale: sale} do
      token = Purchases.purchase_token(sale)

      {:ok, live, html} =
        live(conn, Routes.onboarding_purchase_index_path(conn, :index, sale.id, token))

      assert html =~ "You recently bought"

      form_data = [
        user_password: "secret123456",
        organization_name: "New",
        organization_slug: "new",
        terms_of_service: true
      ]

      live
      |> form("#form-claim", buyer_registration: form_data)
      |> render_submit()

      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
          user: %{email: sale.email, password: "secret123456"}
        })

      assert redirected_to(conn) == Routes.dashboard_index_path(conn, :index)
      {:ok, _live, html} = live(conn, Routes.dashboard_index_path(conn, :index))
      assert html =~ sale.product.name
    end

    test "registers sale as authorized user", %{conn: conn, sale: sale} do
      user = user_fixture(email: sale.email)
      org = org_fixture(user)
      conn = login_user(conn, user)
      token = Purchases.purchase_token(sale)

      {:ok, live, _} =
        live(conn, Routes.onboarding_purchase_index_path(conn, :index, sale.id, token))

      assert has_element?(live, "#assign_org_#{org.slug}")

      live
      |> element("#toggle_show_new_org")
      |> render_click()

      form_data = [
        name: "Acme 2",
        slug: "acme2"
      ]

      {:ok, live, _} =
        live
        |> form("#form-org", org: form_data)
        |> render_submit()
        |> follow_redirect(
          conn,
          Routes.onboarding_purchase_index_path(conn, :index, sale.id, token)
        )

      new_org = Bytepack.Orgs.get_org!(user, "acme2")

      {:ok, _, html} =
        live
        |> element("#assign_org_acme2")
        |> render_click()
        |> follow_redirect(conn, Routes.purchase_show_path(conn, :show, new_org, sale))

      assert html =~ "Purchase registered successfully"
    end

    test "handles sales that has been claimed by the user", %{conn: conn, sale: sale} do
      buyer = user_fixture(email: sale.email)
      buyer_org = org_fixture(buyer)
      Sales.complete_sale!(Bytepack.AuditLog.system(), sale, buyer_org)
      conn = login_user(conn, buyer)
      token = Purchases.purchase_token(sale)

      {:ok, conn} =
        conn
        |> live(Routes.onboarding_purchase_index_path(conn, :index, sale.id, token))
        |> follow_redirect(conn, Routes.purchase_show_path(conn, :show, buyer_org, sale))

      assert get_flash(conn, :info) ==
               "Congratulations! You can now download #{sale.product.name} using the instructions below."
    end

    test "does not register sale with invalid data", %{conn: conn, sale: sale} do
      token = Purchases.purchase_token(sale)

      {:ok, live, _html} =
        live(conn, Routes.onboarding_purchase_index_path(conn, :index, sale.id, token))

      form_data = [
        user_password: "tooshort"
      ]

      html =
        live
        |> form("#form-claim", buyer_registration: form_data)
        |> render_submit()

      assert html =~ "should be at least 12 character(s)"
    end

    test "renders error on invalid purchase for authenticated user", %{conn: conn} do
      conn = login_user(conn, user_fixture())

      {:ok, conn} =
        conn
        |> live(Routes.onboarding_purchase_index_path(conn, :index, 0, "bad"))
        |> follow_redirect(conn, Routes.dashboard_index_path(conn, :index))

      assert get_flash(conn, :error) == "Purchase not found"
    end

    test "renders error on invalid purchase for unauthenticated user", %{conn: conn} do
      {:ok, conn} =
        live(conn, Routes.onboarding_purchase_index_path(conn, :index, 0, "bad"))
        |> follow_redirect(conn, Routes.user_session_path(conn, :new))

      assert get_flash(conn, :error) == "Purchase not found"
    end
  end
end
