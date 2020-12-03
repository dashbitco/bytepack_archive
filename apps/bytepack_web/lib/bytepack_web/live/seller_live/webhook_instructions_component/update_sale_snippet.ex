defmodule BytepackWeb.SellerLive.WebhookInstructionsComponent.UpdateSaleSnippet do
  use BytepackWeb, :live_component

  alias BytepackWeb.SellerLive.WebhookInstructionsComponent

  @impl true
  def render(assigns) do
    ~L"""
    <form class="form-inline" phx-change="update" phx-target="<%= @myself %>">
      <%= radio_buttons [{raw("<code>external_id</code>"), "external_id"}, {raw("<code>id</code>"), "id"}], "update_sale_by_", "update_sale[by]", @by %>

      <input type="text" placeholder="<%= WebhookInstructionsComponent.by_placeholder(@by) %>" class="form-control mr-1" value="<%= @by_value %>" name="update_sale[by_value]">

      <label for="update_sale_product_id"><code>product_id</code></label>
      <select class="custom-select ml-1 mr-1" id="update_sale_product_id" name="update_sale[product_id]">
        <%= options_for_select(Enum.map(@products, &{&1.name, &1.id}), @product_id) %>
      </select>

      <label for="update_sale_external_id"><code>external_id</code></label>
      <input type="text" id="update_sale_external_id" class="form-control ml-1" value="<%= @external_id %>" name="update_sale[external_id]">
    </form>

    <%= snippet(assigns) %>
    """
  end

  defp snippet(assigns) do
    code_snippet(
      ~L"""
      curl -XPATCH \
        --url <%= Routes.webhook_sale_url(@socket, :update, @seller.org) %> \
        --header 'authorization: Bearer <%= @auth_token %>' \
        --header 'bytepack-signature: <%= WebhookInstructionsComponent.http_signature(@seller, @payload) %>' \
        --header 'content-type: application/json' \
        --data '<%= @payload %>'
      """,
      id: "update_sale"
    )
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       by: "external_id",
       by_value: "",
       product_id: hd(assigns.products).id,
       external_id: WebhookInstructionsComponent.random_external_id()
     )
     |> update_payload()}
  end

  @impl true
  def handle_event("update", %{"update_sale" => params}, socket) do
    {:noreply,
     assign(socket,
       by: params["by"],
       by_value: params["by_value"],
       product_id: params["product_id"],
       external_id: params["external_id"]
     )
     |> update_payload()}
  end

  defp update_payload(socket) do
    assign(socket, :payload, payload(socket.assigns))
  end

  defp payload(assigns) do
    ~s({"#{assigns.by}": "#{assigns.by_value}", "sale": {"product_id": #{assigns.product_id}, "external_id": "#{
      assigns.external_id
    }"}})
  end
end
