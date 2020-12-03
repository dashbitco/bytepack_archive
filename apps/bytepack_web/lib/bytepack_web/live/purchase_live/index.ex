defmodule BytepackWeb.PurchaseLive.Index do
  use BytepackWeb, :live_view
  alias Bytepack.Purchases

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_defaults(params, session, [:purchase, :read])
      |> assign(:page_title, "Purchases")
      |> assign_purchases()

    {:ok, socket}
  end

  defp assign_purchases(socket) do
    purchases =
      socket.assigns.current_org
      |> Purchases.list_all_purchases(product: :packages)
      |> Enum.group_by(fn purchase ->
        if purchase.revoked_at do
          :revoked
        else
          :active
        end
      end)
      |> Enum.into(%{revoked: [], active: []})

    assign(socket, :purchases, purchases)
  end

  @impl true
  def render(assigns) do
    ~L"""
    <%= if @purchases.active == [] && @purchases.revoked == [] do %>
      <div class="page-title-box">
        <div class="row">
          <div class="col-9">
            <h4 class="page-title"><%= @page_title %></h4>
          </div>
        </div>
      </div>
      <%= live_component @socket, BytepackWeb.InfoBannerComponent,
            title: "You have not made any purchases yet.",
            description: "As soon as you buy a product hosted on Bytepack, you will be able to find and manage it here.",
            icon: "shopping-bag" %>
    <% end %>

    <%= if @purchases.active != [] do %>
      <div class="page-title-box">
        <div class="row">
          <div class="col-9">
            <h4 class="page-title">Purchases</h4>
          </div>
        </div>
      </div>
      <div class="row purchases__active">
      <%= for purchase <- @purchases.active do %>
        <div class="col-md-4">
          <div class="card ribbon-box">
            <div class="card-body">
              <%= package_count_ribbon(purchase) %>

              <h4 class="card-title"><%= purchase.product.name %></h4>

              <%= text_to_html(purchase.product.description) %>

              <%= live_redirect "Show details", to: Routes.purchase_show_path(@socket, :show, @current_org, purchase), class: "btn btn-primary" %>
            </div>
          </div>
        </div>
      <% end %>
      </div>
    <% end %>

    <%= if @purchases.revoked != [] do %>
      <div class="page-title-box mt-2">
        <div class="row">
          <div class="col-9">
            <h4 class="page-title">Expired purchases</h4>
          </div>
        </div>
      </div>

      <div class="row purchases__revoked">
      <%= for purchase <- @purchases.revoked do %>
        <div class="col-md-4">
          <div class="card ribbon-box">
            <div class="card-body">
              <div class="ribbon purchases__revoked-ribbon ribbon-top ribbon-secondary float-right">
                Expired
              </div>

              <h4 class="card-title"><%= purchase.product.name %></h4>

              <%= text_to_html(purchase.product.description) %>

              <%= live_redirect "Show details", to: Routes.purchase_show_path(@socket, :show, @current_org, purchase), class: "btn btn-primary" %>
            </div>
          </div>
        </div>
      <% end %>
      </div>
    <% end %>
    """
  end

  defp package_count_ribbon(purchase) do
    count = length(purchase.product.packages)
    text = if count == 1, do: "package", else: "packages"

    ~E"""
    <div class="ribbon ribbon-top ribbon-secondary float-right">
      <%= count %> <%= text %>
    </div>
    """
  end
end
