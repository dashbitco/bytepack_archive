defmodule BytepackWeb.Onboarding.PurchaseLive.AssignComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Orgs
  alias Bytepack.Purchases
  alias Bytepack.Sales

  @impl true
  def render(assigns) do
    ~L"""
    <%= if @orgs != [] do %>
      <div class="purchase-page__section-header">Choose an organization to assign the purchase to or create a new one.</div>
    <% else %>
      <div class="purchase-page__section-header">You don't have any organizations yet. You can create a new one and assign your purchase to it.</div>
    <% end %>

    <%= for org <- @orgs do %>
      <div class="purchase-page__select-org-button mb-3 mr-1 d-inline-block">
        <%= button id: "assign_org_#{org.slug}",
          class: "btn-secondary",
          phx_target: @myself,
          phx_click: :assign_org,
          phx_value_slug: org.slug do %>
            <span class="feather-icon icon-home mr-1"></span> <%= org.name %>
          <% end %>
      </div>
    <% end %>

    <%= button id: "toggle_show_new_org",
      class: "btn btn-primary",
      phx_target: @myself,
      phx_click: "toggle_show_new_org" do %>
      <span class="feather-icon icon-plus"></span> Create new organization
    <% end %>

    <%= if @show_new_org? do %>
      <div class="purchase-page__section-header mt-3">
        New organization details
      </div>

      <div class="mt-2">
        <%= live_component @socket, BytepackWeb.OrgLive.FormComponent,
          id: :new_org,
          audit_context: @audit_context,
          current_user: @current_user,
          org: %Orgs.Org{},
          action: :new,
          return_to: Routes.onboarding_purchase_index_path(@socket, :index, @sale, Purchases.purchase_token(@sale)) %>
      </div>
    <% end %>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Orgs.change_org(%Orgs.Org{}, %{email: assigns.current_user.email})
    {:ok, socket |> assign(assigns) |> assign(show_new_org?: false, changeset: changeset)}
  end

  @impl true
  def handle_event("assign_org", %{"slug" => slug}, socket) do
    sale = socket.assigns.sale
    org = Orgs.get_org!(socket.assigns.current_user, slug)
    Sales.complete_sale!(socket.assigns.audit_context, sale, org)

    {:noreply,
     socket
     |> put_flash(:info, "Purchase registered successfully")
     |> push_redirect(to: Routes.purchase_show_path(socket, :show, org, sale))}
  end

  def handle_event("toggle_show_new_org", _, socket) do
    {:noreply, assign(socket, show_new_org?: !socket.assigns.show_new_org?)}
  end
end
