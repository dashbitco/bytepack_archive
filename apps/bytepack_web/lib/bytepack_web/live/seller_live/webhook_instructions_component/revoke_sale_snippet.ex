defmodule BytepackWeb.SellerLive.WebhookInstructionsComponent.RevokeSaleSnippet do
  use BytepackWeb, :live_component

  alias BytepackWeb.SellerLive.WebhookInstructionsComponent

  @impl true
  def render(assigns) do
    ~L"""
    <form class="form-inline" phx-change="update" phx-target="<%= @myself %>">
      <%= radio_buttons [{raw("<code>external_id</code>"), "external_id"}, {raw("<code>id</code>"), "id"}], "revoke_sale_by_", "revoke_sale[by]", @by %>

      <input type="text" placeholder="<%= WebhookInstructionsComponent.by_placeholder(@by) %>" class="form-control mr-1" value="<%= @by_value %>" name="revoke_sale[by_value]">

      <label for="revoke_sale_revoke_reason"><code>revoke_reason</code></label>
      <input type="text" id="revoke_sale_revoke_reason" class="form-control ml-1" value="<%= @revoke_reason %>" name="revoke_sale[revoke_reason]">
    </form>

    <%= snippet(assigns) %>
    """
  end

  defp snippet(assigns) do
    code_snippet(
      ~L"""
      curl -XPATCH \
        --url <%= Routes.webhook_sale_url(@socket, :revoke, @seller.org) %> \
        --header 'authorization: Bearer <%= @auth_token %>' \
        --header 'bytepack-signature: <%= WebhookInstructionsComponent.http_signature(@seller, @payload) %>' \
        --header 'content-type: application/json' \
        --data '<%= @payload %>'
      """,
      id: "revoke_sale"
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
       revoke_reason: "Subscription cancelled"
     )
     |> update_payload()}
  end

  @impl true
  def handle_event("update", %{"revoke_sale" => params}, socket) do
    {:noreply,
     assign(socket,
       by: params["by"],
       by_value: params["by_value"],
       revoke_reason: params["revoke_reason"]
     )
     |> update_payload()}
  end

  defp update_payload(socket) do
    assign(socket, :payload, payload(socket.assigns))
  end

  def payload(assigns) do
    ~s({"#{assigns.by}": "#{assigns.by_value}", "sale": {"revoke_reason": "#{
      assigns.revoke_reason
    }"}})
  end
end
