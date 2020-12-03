Mox.defmock(Bytepack.Stripe.TestHost, for: Bytepack.Stripe.Client.Host)

defmodule Bytepack.StripeHelpers do
  def bypass_stripe() do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    Mox.expect(Bytepack.Stripe.TestHost, :connect_url, fn -> url end)
    bypass
  end
end
