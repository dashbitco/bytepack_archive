defmodule BytepackWeb.ProductLive.Edit do
  use BytepackWeb, :live_view

  alias Bytepack.Sales

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:product, :write])
      |> assign_product(params["id"])
      |> assign(:page_title, "Edit Product")
      |> assign_packages()

    {:ok, socket}
  end

  defp assign_product(socket, id) do
    product = Sales.get_product!(socket.assigns.current_org, id)
    product = %{product | package_ids: Enum.map(product.packages, & &1.id)}
    assign(socket, product: product)
  end

  defp assign_packages(socket) do
    assign(
      socket,
      :packages,
      Bytepack.Packages.list_available_packages(socket.assigns.current_org)
    )
  end
end
