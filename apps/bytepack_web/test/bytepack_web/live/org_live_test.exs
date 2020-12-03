defmodule BytepackWeb.OrgLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Bytepack.SalesFixtures

  setup :register_and_login_user

  describe "New" do
    test "renders new org form", %{conn: conn, user: user} do
      {:ok, live, html} = live(conn, Routes.org_new_path(conn, :new))
      assert html =~ "New Organization"
      assert has_element?(live, "input#form-org_email[value=\"#{user.email}\"]")

      org_name = Bytepack.OrgsFixtures.unique_org_name()

      form_data = [
        name: org_name,
        slug: org_name
      ]

      {:ok, _, html} =
        live
        |> form("#form-org", org: form_data)
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Organization created successfully"
      assert html =~ org_name
    end

    test "ensures only confirmed users can add new orgs", %{conn: conn, user: user} do
      Ecto.Changeset.change(user, confirmed_at: nil) |> Bytepack.Repo.update!()

      {:ok, _, html} =
        live(conn, Routes.org_new_path(conn, :new))
        |> follow_redirect(conn, Routes.dashboard_index_path(conn, :index))

      assert html =~ "You need to confirm your account to access this page"
    end
  end

  describe "Edit" do
    @form_seller_id "#form-seller"

    test "edits org", %{conn: conn, org: org} do
      org
      |> Ecto.Changeset.change(is_seller: false)
      |> Bytepack.Repo.update!()

      {:ok, edit_live, _html} = live(conn, Routes.org_edit_path(conn, :edit, org))

      assert edit_live
             |> form("#form-org", org: [name: ""])
             |> render_change() =~ "can&apos;t be blank"

      {:ok, _, html} =
        edit_live
        |> form("#form-org", org: [name: "updated-org"])
        |> render_submit()
        |> follow_redirect(conn, Routes.org_dashboard_index_path(conn, :index, org))

      assert html =~ "Organization updated successfully"
      assert html =~ "updated-org"

      refute html =~ @form_seller_id
    end

    test "edits seller when org is seller", %{conn: conn, org: org} do
      seller_fixture(org)

      {:ok, edit_live, html} = live(conn, Routes.org_edit_path(conn, :edit, org))
      assert html =~ "Webhooks"

      legal_name = "Los Pollos Hermanos"

      form_data = [
        legal_name: legal_name,
        address_line1: "Address line 1 of #{legal_name}",
        address_line2: "Address line 2 of #{legal_name}",
        address_postal_code: "60000000",
        address_city: "My city",
        address_state: "My state",
        address_country: "BR"
      ]

      {:ok, _, html} =
        edit_live
        |> form(@form_seller_id, seller: form_data)
        |> render_submit()
        |> follow_redirect(conn, Routes.org_dashboard_index_path(conn, :index, org))

      assert html =~ "Seller updated successfully"
      assert html =~ org.name

      seller = Bytepack.Sales.get_seller!(org)

      assert seller.legal_name == legal_name
      assert seller.address_line1 == "Address line 1 of Los Pollos Hermanos"
      assert seller.address_country == "BR"
    end
  end
end
