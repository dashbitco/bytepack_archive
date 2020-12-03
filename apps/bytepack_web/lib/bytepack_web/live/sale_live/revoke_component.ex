defmodule BytepackWeb.SaleLive.RevokeComponent do
  use BytepackWeb, :live_component
  alias Bytepack.Sales

  @impl true
  def render(assigns) do
    ~L"""
    <div class="modal-header">
      <h4 class="modal-title">Revoke <%= Sales.sale_state(@sale) %> sale</h4>
    </div>
    <div class="modal-body">
      <div class="alert alert-warning mb-3 mt-0" role="alert">
        <h4 class="alert-heading"><i class="feather-icon icon-alert-triangle mr-1"></i> Attention!</h4>
        <p class="mb-0">
          If you revoke a sale, the purchase will be shown as "expired" to the buyer
          with the reason given below. Once a sale is revoked, the buyer will no longer
          be able to access its packages. This action is reversible.
        </p>
      </div>
      <%= f = form_for @changeset, "#",
                id: "form-sale-revoke",
                phx_target: @myself,
                phx_change: "validate",
                phx_submit: "save" %>
        <%= input f, :revoke_reason, label: "Reason" %>
        <%= submit "Revoke", phx_disable_with: "Revoking..." %>
      </form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Sales.change_revoke_sale(assigns.sale)
    {:ok, socket |> assign(assigns) |> assign_new(:changeset, fn -> changeset end)}
  end

  @impl true
  def handle_event("validate", %{"sale" => params}, socket) do
    changeset =
      socket.assigns.sale
      |> Sales.change_revoke_sale(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"sale" => params}, socket) do
    case Sales.revoke_sale(socket.assigns.audit_context, socket.assigns.sale, params) do
      {:ok, _sale} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sale revoked successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
