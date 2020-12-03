defmodule BytepackWeb.Admin.SellerLive.Index do
  use BytepackWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_admin(params, session)
      |> assign(:orgs, Bytepack.Orgs.list_orgs())
      |> assign(:page_title, "Sellers")

    {:ok, socket, temporary_assigns: [sellers: []]}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    org = Bytepack.Orgs.get_org!(slug)

    seller =
      if org.is_seller do
        Bytepack.Sales.get_seller!(org)
      else
        %Bytepack.Sales.Seller{id: org.id}
      end

    socket =
      socket
      |> assign(:seller, seller)
      |> assign(:org, org)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_, _url, socket), do: {:noreply, socket}
end
