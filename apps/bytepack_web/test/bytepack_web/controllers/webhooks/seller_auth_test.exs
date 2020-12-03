defmodule BytepackWeb.Webhooks.SellerAuthTest do
  use BytepackWeb.ConnCase, async: true
  use Plug.Test

  alias BytepackWeb.Webhooks.SellerAuth
  alias Bytepack.Sales
  alias Bytepack.Orgs

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures

  def call(conn) do
    SellerAuth.call(conn, SellerAuth.init([]))
  end

  test "call/2 verifies authenticates a user to perform webhook operations" do
    user = user_fixture()
    org = org_fixture(user, is_seller: true)
    membership = Orgs.get_membership!(user, org.slug)

    token = Orgs.Membership.encode_write_token(membership)

    conn =
      conn(:post, "/", %{"org_slug" => org.slug})
      |> put_req_header("authorization", "Bearer #{token}")
      |> call()

    refute conn.halted
    assert %Sales.Seller{} = conn.assigns.current_seller

    conn =
      conn
      |> put_req_header("authorization", "Bearer incorrect-token")
      |> call()

    assert conn.halted

    assert %{"status" => "401", "title" => "Unauthorized"} =
             json_response(conn, :unauthorized)["error"]
  end
end
