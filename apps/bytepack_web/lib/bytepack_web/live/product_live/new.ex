defmodule BytepackWeb.ProductLive.New do
  use BytepackWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:product, :write])
      |> assign(:product, %Bytepack.Sales.Product{})
      |> assign(:page_title, "New Product")
      |> assign_packages()
      |> maybe_redirect_if_not_met_requirements()

    {:ok, socket}
  end

  defp maybe_redirect_if_not_met_requirements(socket) do
    if socket.assigns.packages == [] do
      redirect(socket, to: Routes.product_index_path(socket, :index, socket.assigns.current_org))
    else
      socket
    end
  end

  defp assign_packages(socket) do
    assign(
      socket,
      :packages,
      Bytepack.Packages.list_available_packages(socket.assigns.current_org)
    )
  end
end
