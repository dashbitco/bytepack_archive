defmodule BytepackWeb.SellerLive.FormComponent do
  use BytepackWeb, :live_component
  alias Bytepack.Sales
  alias Bytepack.Sales.Seller
  alias Bytepack.Orgs.Country

  @impl true
  def render(assigns) do
    ~L"""
    <%= f = form_for @changeset, "#",
              id: "form-seller",
              phx_target: @myself,
              phx_change: "validate",
              phx_submit: "save" %>
      <%= input f, :legal_name %>
      <%= input f, :address_line1, label: "Address Line 1" %>
      <%= input f, :address_line2, label: "Address Line 2" %>
      <%= input f, :address_postal_code, label: "Postal code" %>
      <%= input f, :address_city, label: "City" %>
      <%= input f, :address_state, label: "State" %>
      <%= input f, :address_country, label: "Country", using: :select, options: Country.all() %>
      <%= live_submit() %>
    </form>
    """
  end

  @impl true
  def update(%{seller: seller} = assigns, socket) do
    changeset = Seller.changeset(seller)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"seller" => seller_params}, socket) do
    changeset =
      socket.assigns.seller
      |> Seller.changeset(seller_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"seller" => seller_params}, socket) do
    save_seller(socket, socket.assigns.action, seller_params)
  end

  defp save_seller(socket, :edit, seller_params) do
    case Sales.update_seller(socket.assigns.audit_context, socket.assigns.seller, seller_params) do
      {:ok, _seller} ->
        {:noreply,
         socket
         |> put_flash(:info, "Seller updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
