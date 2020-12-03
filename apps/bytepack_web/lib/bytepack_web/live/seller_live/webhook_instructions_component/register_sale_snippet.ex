defmodule BytepackWeb.SellerLive.WebhookInstructionsComponent.RegisterSaleSnippet do
  use BytepackWeb, :live_component

  alias BytepackWeb.SellerLive.WebhookInstructionsComponent

  @impl true
  def render(assigns) do
    ~L"""
    <form class="form-inline" phx-change="update" phx-target="<%= @myself %>">
      <label for="register_sale_product_id"><code>product_id</code></label>
      <select class="custom-select ml-1 mr-1" id="register_sale_product_id" name="register_sale[product_id]">
        <%= options_for_select(Enum.map(@products, &{&1.name, &1.id}), @product_id) %>
      </select>

      <label for="register_sale_email"><code>email</code></label>
      <input type="email" placeholder="E-mail" id="register_sale_email" class="form-control ml-1 mr-1" value="<%= @email %>" name="register_sale[email]">

      <label for="register_sale_external_id"><code>external_id</code></label>
      <input type="text" id="register_sale_external_id" class="form-control ml-1" value="<%= @external_id %>" name="register_sale[external_id]">
    </form>

    <%= snippet(assigns) %>
    """
  end

  defp snippet(assigns) do
    code_snippet(
      ~L"""
      curl -XPOST \
        --url <%= Routes.webhook_sale_url(@socket, :create, @seller.org) %> \
        --header 'authorization: Bearer <%= @auth_token %>' \
        --header 'bytepack-signature: <%= WebhookInstructionsComponent.http_signature(@seller, @payload) %>' \
        --header 'content-type: application/json' \
        --data '<%= @payload %>'
      """,
      id: "register_sale"
    )
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       products: assigns.products,
       product_id: hd(assigns.products).id,
       email: "alice@example.com",
       external_id: WebhookInstructionsComponent.random_external_id()
     )
     |> update_payload()}
  end

  @impl true
  def handle_event("update", %{"register_sale" => params}, socket) do
    {:noreply,
     assign(socket,
       product_id: params["product_id"],
       email: params["email"],
       external_id: params["external_id"]
     )
     |> update_payload()}
  end

  defp update_payload(socket) do
    assign(socket, :payload, payload(socket.assigns))
  end

  defp payload(assigns) do
    ~s({"sale": {"product_id": #{assigns.product_id}, "email": "#{assigns.email}", "external_id": "#{
      assigns.external_id
    }"}})
  end
end
