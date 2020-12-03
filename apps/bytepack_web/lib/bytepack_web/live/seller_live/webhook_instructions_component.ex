defmodule BytepackWeb.SellerLive.WebhookInstructionsComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Sales
  alias Bytepack.Orgs
  alias BytepackWeb.Webhooks.HTTPSignature

  alias BytepackWeb.SellerLive.WebhookInstructionsComponent.{
    RegisterSaleSnippet,
    UpdateSaleSnippet,
    RevokeSaleSnippet
  }

  @impl true
  def render(assigns) do
    ~L"""
    <h5>HTTP signature secret</h5>

    <p>
      In order to send webhook requests to Bytepack and record new sales, you will need to
      sign the request payload with the following secret.
    </p>

    <p>
      The signature is made by using the HMAC with the SHA256 algorithm. Before generating the
      hash you need to concatenate the current timestamp in seconds with the payload.
    </p>

    <p>
      Here is a sample code of how to generate this signature in Elixir:
    </p>

    <%= http_signature_snippet(assigns) %>

    <p>
      The header name is <strong>bytepack-signature</strong> and your secret is
      <strong><%= @signature_secret %></strong>.
    </p>

    <h5 class="mt-4">Registering sales</h5>

    <p>
      To register new sales, you must perform a signed request with your auth token to the relevant
      endpoint. Here is a sample request made with cURL:
    </p>

    <%= live_component @socket, RegisterSaleSnippet, id: :register_sale, seller: @seller, auth_token: @auth_token, products: @products %>

    <p>
      The <code>product_id</code> is the ID of the product shown in your
      <%= link "products page", to: Routes.product_index_path(@socket, :index, @seller.org) %>.
      The <code>email</code> is the e-mail of the user who we will send the package access
      instructions to. The <code>external_id</code> is a unique external code that identifies
      the sale in an external system, such as Stripe Sales ID.
    </p>

    <h5 class="mt-4">Updating sales</h5>

    <p>
      To update a sale, you must perform a signed request with your auth token to the relevant
      endpoint. Here is a sample request made with cURL:
    </p>

    <%= live_component @socket, UpdateSaleSnippet, id: :update_sale, seller: @seller, auth_token: @auth_token, products: @products %>

    <p>
      You must pass either the <code>external_id</code> given on
      registration or the <code>id</code> returned by the registration
      operation. You can update both the <code>product_id</code>
      or the <code>external_id</code>.
    </p>

    <h5 class="mt-4">Revoking sales</h5>

    <p>
      To revoke sales, you must perform a signed request with your auth token to the relevant
      endpoint. Here is a sample request made with cURL:
    </p>

    <%= live_component @socket, RevokeSaleSnippet, id: :revoke_sale, seller: @seller, auth_token: @auth_token, products: @products %>

    <p>
      You must pass either the <code>external_id</code> given on
      registration or the <code>id</code> returned by the registration
      operation. A <code>revoke_reason</code> must also be given.
    </p>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:signature_secret, Sales.encode_http_signature_secret(assigns.seller))
      |> assign_new(:auth_token, fn -> auth_token(assigns.current_membership) end)
      |> assign_products()

    {:ok, socket}
  end

  defp assign_products(socket) do
    products =
      case Sales.list_products(socket.assigns.seller) do
        [] -> [%{id: 1, name: "Example Product #1"}, %{id: 2, name: "Example Product #2"}]
        products -> products
      end

    assign(socket, :products, products)
  end

  defp http_signature_snippet(assigns) do
    code_snippet(
      ~L"""
      secret = "<%= @signature_secret %>"
      timestamp = System.system_time(:second)
      payload = "a JSON payload"
      hmac = :crypto.mac(:hmac, :sha256, "#{timestamp}.#{payload}", secret)
      encoded_hash = Base.encode16(hmac, case: :lower)

      "t=#{timestamp},v1=#{encoded_hash}"
      """,
      id: "http_signature"
    )
  end

  defp auth_token(membership) do
    Orgs.encode_membership_write_token(membership)
  end

  @doc false
  def http_signature(seller, payload) do
    secret = Sales.encode_http_signature_secret(seller)
    {:ok, signature} = HTTPSignature.sign(payload, System.system_time(:second), secret)
    signature
  end

  @doc false
  def random_external_id() do
    8 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  @doc false
  def by_placeholder("id"), do: "ID"
  def by_placeholder("external_id"), do: "External ID"
end
