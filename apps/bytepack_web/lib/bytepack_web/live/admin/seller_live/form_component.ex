defmodule BytepackWeb.Admin.SellerLive.FormComponent do
  use BytepackWeb, :live_component

  alias Bytepack.Orgs.Country
  alias Bytepack.Sales

  @impl true
  def render(assigns) do
    ~L"""
    <div class="modal-header">
      <h4 class="modal-title"><%= @form_title %></h4>
    </div>
    <div class="modal-body">
      <%= f = form_for @changeset, "#",
                id: "form-admin-seller-#{@seller.id}",
                phx_target: @myself,
                phx_change: "validate",
                phx_submit: "save" %>
        <%= input f, :legal_name %>
        <%= input f, :address_line1, label: "Address Line 1" %>
        <%= input f, :address_line2, label: "Address Line 2" %>
        <%= input f, :address_postal_code, label: "Postal code" %>
        <%= input f, :address_city, label: "City" %>
        <%= input f, :address_state, label: "State" %>
        <%= input f, :address_country, label: "Country", using: :select, options: Country.all(), prompt: "Choose..." %>
        <%= live_submit() %>
      </form>
    </div>
    """
  end

  @impl true
  def update(%{seller: seller} = assigns, socket) do
    changeset = Sales.change_seller(seller)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form_title, form_title(seller))
     |> assign(:changeset, changeset)}
  end

  defp form_title(seller) do
    if Ecto.get_meta(seller, :state) == :loaded, do: "Update seller", else: "Activate seller"
  end

  @impl true
  def handle_event("save", %{"seller" => attrs}, socket) do
    case Sales.activate_seller(socket.assigns.org, socket.assigns.seller, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Seller updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"seller" => attrs}, socket) do
    changeset =
      socket.assigns.seller
      |> Sales.change_seller(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end
end
