defmodule BytepackWeb.PurchaseLive.Show do
  use BytepackWeb, :live_view
  alias Bytepack.Purchases
  alias BytepackWeb.PackageHelpers

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:purchase, :read])
      |> assign_purchase(params)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign_selected_package(params)
      |> assign_selected_release_version(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("choose_package_version", %{"version" => version}, socket) do
    %{current_org: current_org, purchase: purchase, selected_package: selected_package} =
      socket.assigns

    url =
      Routes.purchase_show_path(
        socket,
        :show,
        current_org.slug,
        purchase.id,
        selected_package.type,
        selected_package.name,
        version
      )

    {:noreply, push_patch(socket, to: url)}
  end

  defp assign_purchase(socket, params) do
    purchase = Purchases.get_any_purchase_with_releases!(socket.assigns.current_org, params["id"])

    socket
    |> assign(:purchase, purchase)
    |> assign(:page_title, purchase.product.name)
    |> assign(:package_count, length(purchase.product.packages))
  end

  defp assign_selected_package(socket, params) do
    product = socket.assigns.purchase.product

    selected_package =
      with %{"package_name" => package_name, "package_type" => package_type} <- params,
           %Bytepack.Packages.Package{} = package <-
             Enum.find(product.packages, &(&1.name == package_name and &1.type == package_type)) do
        package
      else
        _ -> hd(product.packages)
      end

    assign(socket, :selected_package, selected_package)
  end

  defp assign_selected_release_version(socket, params) do
    with %{"release_version" => release_version} <- params do
      package = socket.assigns.selected_package
      selected_release = Bytepack.Hex.get_hex_release!(package, release_version)
      assign(socket, :selected_release, selected_release)
    else
      _ ->
        latest_release = Bytepack.Hex.latest_release(socket.assigns.selected_package)
        assign(socket, :selected_release, latest_release)
    end
  end

  def package_button(assigns, package) do
    ~L"""
    <div class="<%= if package.id == @selected_package.id do %>bg-light<% end %>">
      <%= live_patch to: Routes.purchase_show_path(@socket, :show, @current_org, @purchase, package.type, package.name), class: "text-body d-block p-2" do %>
        <div class="d-flex">
          <div class="product-packages__menu-icon flex-grow-0">
            <%= PackageHelpers.package_icon(@socket, package.type) %>
          </div>
          <div class="ml-2">
            <h5 class="my-1"><%= package.name %></h5>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
