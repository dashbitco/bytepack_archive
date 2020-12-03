defmodule BytepackWeb.DashboardLive.Index do
  use BytepackWeb, :live_view
  alias Bytepack.{Accounts, Orgs, Sales, Purchases}

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:user, :dashboard])
      |> assign(:page_title, "Dashboard")
      |> assign_invitations()
      |> assign_orgs()
      |> assign_org_purchases()
      |> assign_seller_status()
      |> assign_org_products()
      |> assign_pending_purchases()

    {:ok, socket, temporary_assigns: [invitations: nil]}
  end

  @impl true
  def handle_event("accept_invitation", %{"id" => id}, socket) do
    membership =
      Orgs.accept_invitation!(socket.assigns.audit_context, socket.assigns.current_user, id)

    {:noreply,
     socket
     |> put_flash(:info, "Invitation was accepted")
     |> push_redirect(to: Routes.org_dashboard_index_path(socket, :index, membership.org))}
  end

  @impl true
  def handle_event("reject_invitation", %{"id" => id}, socket) do
    Orgs.reject_invitation!(socket.assigns.audit_context, socket.assigns.current_user, id)

    {:noreply,
     socket
     |> put_flash(:info, "Invitation was rejected")
     |> assign_invitations()}
  end

  @impl true
  def handle_event("confirmation_resend", _, socket) do
    socket.assigns.current_user
    |> Accounts.deliver_user_confirmation_instructions(
      &Routes.user_confirmation_url(socket, :confirm, &1)
    )

    {:noreply,
     socket
     |> put_flash(:info, "You will receive an e-mail with instructions shortly.")}
  end

  defp product_box(link, name, org, to) do
    assigns = %{}

    ~L"""
    <div class="card product-box-component">
      <div class="card-body product-box-component__body">
        <div><h5 class="mt-1"><%= name %></h5></div>
        <div class="text-muted"><%= org.name %></div>
        <%= live_redirect link, to: to, class: "w-100 btn btn-primary mt-2" %>
      </div>
    </div>
    """
  end

  defp assign_invitations(socket) do
    invitations = Orgs.list_invitations_by_user(socket.assigns.current_user)

    assign(socket, :invitations, invitations)
  end

  defp assign_orgs(socket) do
    orgs = Orgs.list_orgs(socket.assigns.current_user)
    assign(socket, :orgs, orgs)
  end

  defp assign_org_purchases(socket) do
    org_purchases =
      socket.assigns.orgs
      |> Enum.map(& &1.id)
      |> Purchases.list_available_purchases_by_buyer_ids(product: :seller)

    assign(socket, :org_purchases, org_purchases)
  end

  defp assign_seller_status(socket) do
    status =
      cond do
        Enum.any?(socket.assigns.orgs, & &1.is_seller) ->
          :yes

        socket.assigns.org_purchases == [] ->
          :maybe

        true ->
          :no
      end

    assign(socket, :seller_status, status)
  end

  defp assign_org_products(socket) do
    if socket.assigns.seller_status == :yes do
      org_products =
        socket.assigns.orgs
        |> Enum.map(& &1.id)
        |> Sales.list_products_by_seller_ids()

      assign(socket, :org_products, org_products)
    else
      assign(socket, :org_products, [])
    end
  end

  defp assign_pending_purchases(socket) do
    pending_purchases =
      Purchases.list_pending_purchases_by_email(socket.assigns.current_user.email)

    assign(socket, :pending_purchases, pending_purchases)
  end

  defp find_org(orgs, id) do
    Enum.find(orgs, &(&1.id == id))
  end

  defp has_any_notification?(orgs, invitations, pending_purchases) do
    Enum.all?([orgs, invitations, pending_purchases], &Enum.empty?/1)
  end

  defp has_invitations?(invitations) do
    Enum.any?(invitations)
  end

  defp has_pending_purchases?(pending_purchases) do
    Enum.any?(pending_purchases)
  end
end
