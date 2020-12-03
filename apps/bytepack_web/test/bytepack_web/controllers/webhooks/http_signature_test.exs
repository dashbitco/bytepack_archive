defmodule BytepackWeb.Webhooks.HTTPSignatureTest do
  use BytepackWeb.ConnCase, async: true
  use Plug.Test

  alias Bytepack.Sales
  alias BytepackWeb.Webhooks.HTTPSignature

  import Bytepack.AccountsFixtures
  import Bytepack.OrgsFixtures
  import Bytepack.SalesFixtures

  defp cache_raw_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, [])
    put_in(conn.assigns[:raw_body], body)
  end

  def call(conn) do
    HTTPSignature.call(conn, HTTPSignature.init([]))
  end

  describe "plug" do
    test "call/2 verifies the autenticity of the signature" do
      org = org_fixture(user_fixture(), is_seller: true)
      seller = seller_fixture(org)

      payload = "{\"data\": \"a-sample-payload\"}"
      timestamp = System.system_time(:second)

      {:ok, signature} =
        HTTPSignature.sign(
          payload,
          timestamp,
          Sales.encode_http_signature_secret(seller)
        )

      conn =
        conn(:post, "/", payload)
        |> cache_raw_body()
        |> assign(:current_seller, seller)
        |> put_req_header("bytepack-signature", signature)
        |> call()

      refute conn.halted

      conn =
        conn(:post, "/", payload)
        |> cache_raw_body()
        |> assign(:current_seller, seller)
        |> put_req_header("bytepack-signature", "a-wrong-signature")
        |> call()

      assert conn.halted
      assert response(conn, :bad_request)

      assert_raise HTTPSignature.RawBodyNotPresentError, fn ->
        conn(:post, "/", payload)
        |> assign(:current_seller, seller)
        |> put_req_header("bytepack-signature", signature)
        |> call()
      end
    end
  end

  describe "sign and verify" do
    test "signs a payload correctly" do
      payload = "{\"data\": \"a-sample-payload\"}"
      secret = "a-secret"
      timestamp = 1_595_960_507

      assert {:ok, signature} = HTTPSignature.sign(payload, timestamp, secret)

      assert signature ==
               "t=1595960507,v1=7fc4cf4a0eb561fd819e1769b04f5a7eaa0f4359d14dc5fd4cb045e3de9b26db"
    end

    defmodule FakeSystem do
      def system_time(:second), do: 1_595_960_807
    end

    test "verifies the signature" do
      payload = "{\"data\": \"a-sample-payload\"}"
      secret = "a-secret"
      header = "t=1595960507,v1=7fc4cf4a0eb561fd819e1769b04f5a7eaa0f4359d14dc5fd4cb045e3de9b26db"

      assert :ok = HTTPSignature.verify(header, payload, secret, system: FakeSystem)

      assert {:error, "signature is incorrect"} =
               HTTPSignature.verify(header, "a-different-payload", secret, system: FakeSystem)

      assert {:error, "signature is incorrect"} =
               HTTPSignature.verify(header, payload, "another-secret", system: FakeSystem)

      header = "t=1595950507,v1=7fc4cf4a0eb561fd819e1769b04f5a7eaa0f4359d14dc5fd4cb045e3de9b26db"

      assert {:error, "signature is too old"} =
               HTTPSignature.verify(header, payload, secret, system: FakeSystem)

      header = "t=1595950507,v2=7fc4cf4a0eb561fd819e1769b04f5a7eaa0f4359d14dc5fd4cb045e3de9b26db"

      assert {:error, "signature is in a wrong format or is missing v1 schema"} =
               HTTPSignature.verify(header, payload, secret, system: FakeSystem)

      header = "rubbish"

      assert {:error, "signature is in a wrong format or is missing v1 schema"} =
               HTTPSignature.verify(header, payload, secret, system: FakeSystem)
    end
  end
end
