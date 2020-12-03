defmodule BytepackWeb.ProductLive.Index do
  use BytepackWeb, :live_view

  alias Bytepack.Packages
  alias Bytepack.Sales
  alias BytepackWeb.PackageHelpers

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:product, :read])
      |> assign(:page_title, "Products")
      |> assign_products()
      |> assign_blank_banner()

    {:ok, socket}
  end

  defp assign_products(socket) do
    products = Sales.list_products(socket.assigns.current_org)
    assign(socket, :products, products)
  end

  defp assign_blank_banner(socket) do
    blank_banner =
      cond do
        socket.assigns.products != [] ->
          false

        Packages.list_available_packages(socket.assigns.current_org) == [] ->
          :packages

        true ->
          :products
      end

    assign(socket, :blank_banner, blank_banner)
  end

  defp blank_banner(:packages, assigns) do
    ~L"""
    <%= live_component @socket, BytepackWeb.InfoBannerComponent,
    title: "You have not published any packages yet.",
    description: "In order to create products, you need to publish a package first.",
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
    title: "You have not added any products yet.",
    description: "As soon as you create a product on Bytepack, you will be able to view and manage it here.",
    icon: "grid" do %>
      <%= live_redirect to: Routes.product_new_path(@socket, :new, @current_org), id: "empty-page-new-product-button", class: "btn btn-sm info-banner__button" do %>
        <span class="feather-icon icon-plus mr-1"></span>Add new product
      <% end %>
    <% end %>
    """
  end
end
