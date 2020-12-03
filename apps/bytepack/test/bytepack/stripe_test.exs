defmodule Bytepack.StripeTest do
  use Bytepack.DataCase, async: true

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures

  alias Bytepack.Sales
  alias Bytepack.Sales.Seller
  alias Bytepack.Stripe

  describe "oauth_callback/2" do
    import Bytepack.StripeHelpers

    setup do
      alice = user_fixture()
      acme = org_fixture(alice, %{is_seller: true})
      seller = Sales.get_seller!(acme)

      {:ok, %{seller: seller}}
    end

    defp stripe_state(seller) do
      url =
        seller
        |> Stripe.oauth_url()
        |> URI.parse()

      URI.decode_query(url.query)["state"]
    end

    defp expect_stripe_token(user_id) do
      Bypass.expect(bypass_stripe(), fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert ["Bearer " <> _] = Plug.Conn.get_req_header(conn, "authorization")
        assert body =~ "code=stripecode"

        Plug.Conn.resp(conn, 200, ~s|{"stripe_user_id": "#{user_id}"}|)
      end)
    end

    test "sets the stripe_user_id to the given seller id", %{seller: seller} do
      expect_stripe_token("acct_123456")
      state = stripe_state(seller)

      {:ok, %Seller{} = seller} =
        Stripe.oauth_callback(%{"code" => "stripecode", "state" => state})

      assert seller.id == seller.id
      assert seller.stripe_user_id == "acct_123456"
    end

    test "does not set the stripe_user_id if it is already set", %{seller: seller} do
      expect_stripe_token("acct_123456")

      seller
      |> Ecto.Changeset.change(stripe_user_id: "prev_123456")
      |> Repo.update!()

      state = stripe_state(seller)

      assert Stripe.oauth_callback(%{"code" => "stripecode", "state" => state}) == :error
    end

    test "fails if params does not contain code", %{seller: seller} do
      state = stripe_state(seller)

      assert Stripe.oauth_callback(%{"error" => "oops", "state" => state}) == :error
    end

    test "fails if state is invalid" do
      assert Stripe.oauth_callback(%{"code" => "stripecode", "state" => "what"}) == :error
    end

    test "fails if state is an invalid seller" do
      expect_stripe_token("acct_123456")
      state = stripe_state(%Seller{id: 0})

      assert Stripe.oauth_callback(%{"code" => "stripecode", "state" => state}) == :error
    end

    @tag :capture_log
    test "fails if cannot hear back from Stripe", %{seller: seller} do
      Bypass.expect(bypass_stripe(), &Plug.Conn.resp(&1, 403, ""))

      assert Stripe.oauth_callback(%{
               "code" => "stripecode",
               "state" => stripe_state(seller)
             }) == :error
    end
  end
end
