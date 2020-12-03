defmodule BytepackWeb.Extensions.Plug.BodyReaderTest do
  use BytepackWeb.ConnCase, async: true
  use Plug.Test

  alias BytepackWeb.Extensions.Plug.BodyReader

  test "cache_raw_body/2 caches the original body" do
    payload = "{\"data\": \"another-payload\"}"

    conn = conn(:post, "/", payload)

    assert {:ok, body, conn} = BodyReader.cache_raw_body(conn, [])

    assert body == payload
    assert %Plug.Conn{assigns: %{raw_body: raw_body}} = conn
    assert IO.iodata_to_binary(raw_body) == payload
  end
end
