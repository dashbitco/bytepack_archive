defmodule BytepackWeb.SaleLive.FormComponent do
  use BytepackWeb, :live_component
  alias Bytepack.Sales

  @impl true
  def render(assigns) do
    ~L"""
    <div class="modal-header">
      <h4 class="modal-title"><%= @title %></h4>
    </div>
    <div class="modal-body">
      <%= f = form_for @changeset, "#",
                id: "form-sale",
                phx_target: @myself,
                phx_change: "validate",
                phx_submit: "save" %>
        <%= input f, :product_id, label: "Product", using: :select, options: @products %>
        <%= input f, :email, phx_debounce: "blur", autocomplete: "off", disabled: @action == :edit %>
        <%= input f, :external_id, label: "External ID", phx_debounce: "blur", autocomplete: "off",
              hint: "The external ID is optional but should be unique. It is often used to " <>
                    "associate to the payment processor ID, such as Stripe transaction ID." %>

        <%= if @action == :edit do %>
          <div class="float-right mt-2">
            <%= if Sales.can_be_deleted?(@sale) do %>
              <button id="btn-delete-sale" type="button" class="btn btn-danger"
                phx-click="delete_sale" phx-target="<%= @myself %>"
                data-toggle="tooltip"
                data-original-title="This action completely erases this sale from the system. Be careful: this cannot be reverted"
                data-confirm="Are you sure you want to delete this sale? This can't be reverted.">
                Delete
              </button>
            <% end %>
          </div>
        <% end %>

        <%= live_submit() %>
      </form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Sales.change_sale(assigns.sale)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:title, page_title(assigns.action, assigns.sale))
     |> assign_new(:products, fn -> products_for_select(assigns.seller) end)
     |> assign_new(:changeset, fn -> changeset end)}
  end

  defp products_for_select(seller) do
    seller
    |> Sales.list_products()
    |> Enum.map(&{&1.name, &1.id})
  end

  defp page_title(:new, _sale), do: "New sale"
  defp page_title(:edit, sale), do: "Edit #{Sales.sale_state(sale)} sale"

  @impl true
  def handle_event("validate", %{"sale" => params}, socket) do
    changeset =
      socket.assigns.sale
      |> Sales.change_sale(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"sale" => params}, socket) do
    save_sale(params, socket.assigns.action, socket)
  end

  @impl true
  def handle_event("delete_sale", _, %{assigns: assigns} = socket) do
    redirect_or_assign_changeset(
      Sales.delete_sale(assigns.audit_context, assigns.sale),
      "Sale deleted successfully",
      socket
    )
  end

  defp save_sale(params, :new, %{assigns: assigns} = socket) do
    case Sales.create_sale(assigns.audit_context, assigns.seller, params) do
      {:ok, sale} ->
        Sales.deliver_create_sale_email(
          sale,
          &Routes.onboarding_purchase_index_url(socket, :index, sale.id, &1)
        )

        {:noreply,
         socket
         |> put_flash(:info, "Sale created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_sale(params, :edit, %{assigns: assigns} = socket) do
    redirect_or_assign_changeset(
      Sales.update_sale(assigns.audit_context, assigns.sale, params),
      "Sale updated successfully",
      socket
    )
  end

  defp redirect_or_assign_changeset(result, info_message, socket) do
    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, info_message)
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
