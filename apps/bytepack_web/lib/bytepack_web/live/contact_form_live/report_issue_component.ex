defmodule BytepackWeb.ContactFormLive.ReportIssueFormComponent do
  use BytepackWeb, :live_component

  alias Bytepack.{Orgs, Purchases}

  @impl true
  def render(assigns) do
    ~L"""
    <form id="report-issue-form" class="contact-form" phx-change="select_purchase" phx-target="<%= @myself %>">
      <%= if @purchases == [] do %>
        <p class="mb-0">
          You currently do not own any products on Bytepack.
        </p>
      <% else %>
      <label for="report_issue_product">Purchase that you experienced an issue with</label>
        <select name="purchase_id" id="report_issue_product" name="org" class="form-control custom-select">
          <option value="none">Please select a purchase...</option>
          <%= for purchase <- @purchases do %>
            <option value="<%= purchase.id %>" <%= if assigns[:selected_purchase] && purchase.id == @selected_purchase.id do %>selected="selected"<% end %>>
              <%= purchase.product.name %> (from <%= purchase.product.seller.name %>)
            </option>
          <% end %>
        </select>
        <%= if assigns[:selected_purchase] do %>
          <div class="mt-4 text-center mb-2">
            <div class="pb-3">
              <strong><%= @selected_purchase.product.name %></strong> is published by <strong><%= @selected_purchase.product.seller.name %></strong>
            </div>
            <div class="text-center">
              <%= link to: "mailto:" <> @selected_purchase.product.seller.email, class: "btn btn-light" do %>
                <span class="feather-icon icon-mail mr-1"></span> Contact by email
              <% end %>

              <%= link to: @selected_purchase.product.url, target: "_blank", rel: "noopener", class: "btn btn-light" do %>
                <span class="feather-icon icon-external-link mr-1"></span> Visit website
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </form>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:current_user, assigns.current_user)
      |> assign_purchases()

    {:ok, socket}
  end

  @impl true
  def handle_event("select_purchase", %{"purchase_id" => "none"}, socket) do
    socket = assign(socket, :selected_purchase, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_purchase", %{"purchase_id" => purchase_id}, socket) do
    selected_purchase = Enum.find(socket.assigns.purchases, &(inspect(&1.id) == purchase_id))
    socket = assign(socket, :selected_purchase, selected_purchase)

    {:noreply, socket}
  end

  def assign_purchases(socket) do
    current_user = socket.assigns[:current_user]

    purchases =
      current_user
      |> Orgs.list_orgs()
      |> Enum.map(fn org ->
        Purchases.list_all_purchases(org, product: :seller)
      end)
      |> List.flatten()

    socket
    |> assign(:purchases, purchases)
  end
end
