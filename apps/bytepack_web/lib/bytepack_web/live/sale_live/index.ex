defmodule BytepackWeb.SaleLive.Index do
  use BytepackWeb, :live_view
  alias Bytepack.Sales
  alias Bytepack.Packages

  @requirements_for_new_sale [:products, :packages]

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:sale, :read])
      |> assign(:page_title, "Sales")
      |> assign_seller()
      |> assign_sales()
      |> assign_blank_banner()
      |> maybe_redirect_if_not_met_requirements()

    {:ok, socket, temporary_assigns: [sales: []]}
  end

  defp maybe_redirect_if_not_met_requirements(socket) do
    if socket.assigns.live_action == :new &&
         socket.assigns.blank_banner in @requirements_for_new_sale do
      redirect(socket, to: Routes.sale_index_path(socket, :index, socket.assigns.current_org))
    else
      socket
    end
  end

  defp assign_seller(socket) do
    assign(socket, :seller, Sales.get_seller!(socket.assigns.current_org))
  end

  defp assign_sales(socket) do
    sales = Sales.list_sales(socket.assigns.seller)
    assign(socket, :sales, sales)
  end

  defp assign_blank_banner(socket) do
    blank_banner =
      cond do
        socket.assigns.sales != [] ->
          false

        Packages.list_available_packages(socket.assigns.current_org) == [] ->
          :packages

        Sales.list_products(socket.assigns.seller) == [] ->
          :products

        true ->
          :sales
      end

    assign(socket, :blank_banner, blank_banner)
  end

  defp blank_banner(:packages, assigns) do
    ~L"""
    <%= live_component @socket, BytepackWeb.InfoBannerComponent,
    title: "You have not published any packages yet.",
    description: "In order to register sales, you need to publish a package first.",
    icon: "package" do %>
      <%= live_redirect to: Routes.package_new_path(@socket, :new, @current_org), id: "empty-page-new-package-button", class: "btn btn-sm info-banner__button" do %>
        <span class="feather-icon icon-plus mr-1"></span>Add new package
      <% end %>
    <% end %>
    """
  end

  defp blank_banner(:products, assigns) do
    ~L"""
    <%= live_component @socket, BytepackWeb.InfoBannerComponent,
    title: "You have not recorded any products yet.",
    description: "In order to register sales, you need to create a product first.",
    icon: "grid" do %>
      <%= live_redirect to: Routes.product_new_path(@socket, :new, @current_org), id: "empty-page-new-product-button", class: "btn btn-sm info-banner__button" do %>
        <span class="feather-icon icon-plus mr-1"></span>Add new product
      <% end %>
    <% end %>
    """
  end

  defp blank_banner(:sales, assigns) do
    ~L"""
    <%= live_component @socket, BytepackWeb.InfoBannerComponent,
    title: "You have not recorded any sales yet.",
    description: "As soon as you sell a product on Bytepack, you will be able to find relevand sale information here.",
    icon: "trending-up" do %>
      <%= live_redirect to: Routes.sale_index_path(@socket, :new, @current_org), id: "empty-page-new-sale-button", class: "btn btn-sm info-banner__button" do %>
        <span class="feather-icon icon-plus mr-1"></span>Add new sale
      <% end %>
      <%= live_redirect to: Routes.org_edit_path(@socket, :edit, @current_org) <> "#webhooks", id: "empty-page-webhook-button", class: "ml-2 btn btn-sm info-banner__button" do %>
        <span class="feather-icon icon-info mr-1"></span>Learn about sales webhooks
      <% end %>
    <% end %>
    """
  end

  @impl true
  def handle_params(%{"id" => id}, _path, socket) do
    sale = Sales.get_sale!(socket.assigns.seller, id)
    {:noreply, assign(socket, :sale, sale)}
  end

  def handle_params(_params, _path, socket) do
    {:noreply, assign(socket, :sale, %Sales.Sale{})}
  end

  @impl true
  def handle_event("activate_sale", %{"id" => id}, socket) do
    sale = Sales.get_sale!(socket.assigns.seller, id)
    {:ok, _} = Sales.activate_sale(socket.assigns.audit_context, sale)
    {:noreply, socket |> put_flash(:info, "Sale reactivated successfully") |> assign_sales()}
  end

  defp sale_state(sale) do
    sale
    |> Sales.sale_state()
    |> to_string()
    |> String.capitalize()
  end
end
