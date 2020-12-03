defmodule BytepackWeb.Admin.SellerLiveTest do
  use BytepackWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Index" do
    test "list all orgs", %{conn: conn} do
      user = Bytepack.AccountsFixtures.staff_fixture(confirmed: true)
      org = Bytepack.OrgsFixtures.org_fixture(user, %{is_seller: false})

      conn = login_user(conn, user)

      {:ok, _edit_live, html} = live(conn, Routes.admin_seller_index_path(conn, :edit, org))

      assert html =~ "Activate seller"
      assert html =~ org.name
    end

    test "does not allow access of non staff users", %{conn: conn} do
      user = Bytepack.AccountsFixtures.user_fixture(confirmed: true)
      Bytepack.OrgsFixtures.org_fixture(user, %{is_seller: false})

      user = Bytepack.Repo.update!(Ecto.Changeset.change(user, %{is_staff: false}))
      conn = login_user(conn, user)

      assert_raise BytepackWeb.UserAuth.NotStaffError, fn ->
        live(conn, Routes.admin_seller_index_path(conn, :index))
      end
    end
  end

  describe "Activate Seller" do
    test "activate organization as a seller", %{conn: conn} do
      user = Bytepack.AccountsFixtures.staff_fixture(confirmed: true)
      org = Bytepack.OrgsFixtures.org_fixture(user, %{is_seller: false})

      conn = login_user(conn, user)

      {:ok, edit_live, _html} = live(conn, Routes.admin_seller_index_path(conn, :edit, org))

      form_params = [
        legal_name: "Acme Inc.",
        address_city: "Gothan",
        address_line1: "5th av",
        address_country: "US"
      ]

      {:ok, _, html} =
        edit_live
        |> form("#form-admin-seller-#{org.id}", seller: form_params)
        |> render_submit()
        |> follow_redirect(conn, Routes.admin_seller_index_path(conn, :index))

      assert html =~ "Seller updated successfully"
      assert html =~ "Edit seller"

      org = Bytepack.Repo.get!(Bytepack.Orgs.Org, org.id)

      assert org.is_seller
    end
  end
end
