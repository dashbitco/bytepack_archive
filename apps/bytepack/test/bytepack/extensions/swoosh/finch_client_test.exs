defmodule Bytepack.Extensions.Swoosh.FinchClientTest do
  use ExUnit.Case, async: true

  defmodule TestMailer do
    use Swoosh.Mailer,
      otp_app: :bytepack,
      adapter: Swoosh.Adapters.Postmark,
      api_key: "dummy"
  end

  test "integration" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, fn conn ->
      Plug.Conn.resp(conn, 200, ~s<{"Message": "OK"}>)
    end)

    opts = [base_url: "http://localhost:#{bypass.port}"]
    email = Swoosh.Email.new(from: "alice@example.com", to: "bob@example.com", subject: "test")

    assert {:ok, %{}} = TestMailer.deliver(email, opts)

    Bypass.down(bypass)
    assert {:error, %Mint.TransportError{reason: :econnrefused}} = TestMailer.deliver(email, opts)
  end
end
