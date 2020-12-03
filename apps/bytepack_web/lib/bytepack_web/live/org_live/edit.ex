defmodule BytepackWeb.OrgLive.Edit do
  use BytepackWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:org, :edit])
      |> assign(:page_title, "Organization Settings")
      |> assign_seller()

    {:ok, socket}
  end

  defp assign_seller(socket) do
    seller =
      socket.assigns.current_org.is_seller &&
        Bytepack.Sales.get_seller!(socket.assigns.current_org)

    assign(socket, :seller, seller)
  end
end
