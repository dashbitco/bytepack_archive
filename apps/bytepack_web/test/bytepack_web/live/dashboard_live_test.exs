defmodule BytepackWeb.DashboardLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.SalesFixtures
  alias Bytepack.{Accounts, Repo}

  setup :register_and_login_user

  @reach_out_text ~s|Are you interested in delivering products through Bytepack?|

  describe "Index" do
    test "shows data", %{conn: conn} do
      {:ok, index_live, _} = live(conn, Routes.dashboard_index_path(conn, :index))
      html = render(index_live)
      assert html =~ "Welcome"
    end

    test "accept an invitation", %{conn: conn, user: user} do
      org = org_fixture(user_fixture())
      invitation = invitation_fixture(org, email: user.email)

      {:ok, index_live, html} = live(conn, Routes.dashboard_index_path(conn, :index))
      assert html =~ "You have been invited to join #{org.name}"

      {:ok, _, html} =
        index_live
        |> element("#invitation-#{invitation.id} a", "Accept")
        |> render_click()
        |> follow_redirect(conn, Routes.org_dashboard_index_path(conn, :index, org))

      assert html =~ "Invitation was accepted"
    end

    test "reject an invitation", %{conn: conn, user: user} do
      org = org_fixture(user_fixture())
      invitation = invitation_fixture(org, email: user.email)

      {:ok, index_live, html} = live(conn, Routes.dashboard_index_path(conn, :index))
      assert html =~ "You have been invited to join #{org.name}"

      html =
        index_live
        |> element("#invitation-#{invitation.id} a", "Reject")
        |> render_click()

      assert html =~ "Invitation was rejected"
      refute html =~ org.name
    end

    test "resend confirmation", %{conn: conn, user: user} do
      Repo.update(Ecto.Changeset.change(user, %{confirmed_at: nil}))

      {:ok, index_live, html} = live(conn, Routes.dashboard_index_path(conn, :index))
      assert html =~ "You have not confirmed your account"
      assert html =~ "To access all Bytepack features you need to confirm your account first."

      html =
        index_live
        |> element("a", "resend the confirmation")
        |> render_click()

      assert html =~ "You will receive an e-mail with instructions shortly."
      assert Repo.get_by(Accounts.UserToken, user_id: user.id, context: "confirm")

      refute html =~ "We noticed that you have purchased"
      refute html =~ "claim this purchase here"
    end

    test "resend confirmation when invitations are pending", %{conn: conn, user: user} do
      org = org_fixture(user_fixture())
      invitation_fixture(org, email: user.email)

      Repo.update(Ecto.Changeset.change(user, %{confirmed_at: nil}))

      {:ok, index_live, _html} = live(conn, Routes.dashboard_index_path(conn, :index))

      info_message =
        index_live
        |> element(".alert-info")
        |> render()

      assert info_message =~ "You have been invited to join"
      assert info_message =~ org.name

      assert info_message =~
               "In order to accept invitations you need to confirm your account first."

      html =
        index_live
        |> element("a", "resend the confirmation")
        |> render_click()

      assert html =~ "You will receive an e-mail with instructions shortly."
      assert Repo.get_by(Accounts.UserToken, user_id: user.id, context: "confirm")
    end

    test "shows list of purchases", %{conn: conn, org: org, user: user} do
      seller_org = org_fixture(user_fixture())
      product1 = product_fixture(seller_org)
      product2 = product_fixture(seller_org)

      sale1 = sale_fixture(seller_org, product1, email: user.email)
      sale2 = sale_fixture(seller_org, product2, email: user.email)

      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale1, org)
      Bytepack.Sales.complete_sale!(Bytepack.AuditLog.system(), sale2, org)

      {:ok, _index_live, html} = live(conn, Routes.dashboard_index_path(conn, :index))

      assert html =~ ~s|<h5 class="mt-1">#{product1.name}</h5>|
      assert html =~ ~s|<h5 class="mt-1">#{product2.name}</h5>|
      refute html =~ @reach_out_text
    end

    test "shows list of pending purchases", %{conn: conn, user: user} do
      seller_org = org_fixture(user_fixture())
      product1 = product_fixture(seller_org)
      product2 = product_fixture(seller_org)

      sale_fixture(seller_org, product1, email: user.email)
      sale_fixture(seller_org, product2, email: user.email)

      {:ok, _index_live, html} = live(conn, Routes.dashboard_index_path(conn, :index))

      assert html =~ "We noticed that you have purchased"
      assert html =~ product1.name
      assert html =~ product2.name
      assert html =~ "claim this purchase here"
    end

    test "shows list of pending purchases even with pending confirmation", %{
      conn: conn,
      user: user
    } do
      Repo.update(Ecto.Changeset.change(user, %{confirmed_at: nil}))

      seller_org = org_fixture(user_fixture())
      product1 = product_fixture(seller_org)
      product2 = product_fixture(seller_org)

      sale_fixture(seller_org, product1, email: user.email)
      sale_fixture(seller_org, product2, email: user.email)

      {:ok, _, html} = live(conn, Routes.dashboard_index_path(conn, :index))

      assert html =~ "We noticed that you have purchased"
      assert html =~ product1.name
      assert html =~ product2.name
      assert html =~ "claim this purchase here"

      refute html =~ "You have not confirmed your account"
    end

    test "shows list of products", %{conn: conn, org: org} do
      product1 = product_fixture(org)
      product2 = product_fixture(org)

      {:ok, _index_live, html} = live(conn, Routes.dashboard_index_path(conn, :index))

      assert html =~ ~s|<h5 class="mt-1">#{product1.name}</h5>|
      assert html =~ ~s|<h5 class="mt-1">#{product2.name}</h5>|
    end

    test "does not show a list of products if org is not a seller", %{conn: conn, org: org} do
      org
      |> Ecto.Changeset.change(is_seller: false)
      |> Bytepack.Repo.update!()

      {:ok, _index_live, html} = live(conn, Routes.dashboard_index_path(conn, :index))
      assert html =~ @reach_out_text
    end

    test "suggests creating a new organization, if user does not belong to any", %{conn: conn} do
      user = Bytepack.AccountsFixtures.user_fixture(confirmed: true)
      conn = login_user(conn, user)

      {:ok, index_live, html} = live(conn, Routes.dashboard_index_path(conn, :index))

      assert html =~ "You don&apos;t belong to any organizations."

      {:ok, _, html} =
        index_live
        |> element("#new-organization-button")
        |> render_click()
        |> follow_redirect(conn)

      assert html =~ ~s|<h4 class="page-title">New Organization</h4>|
    end
  end
end
