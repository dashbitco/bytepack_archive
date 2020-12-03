defmodule BytepackWeb.Onboarding.PurchaseLive.Index do
  use BytepackWeb, :live_view

  alias Bytepack.Purchases
  alias Bytepack.Orgs

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> MountHelpers.assign_maybe_logged_in_defaults(session["user_token"])
      |> assign_sale(params)

    {:ok, socket, layout: false}
  end

  defp assign_sale(socket, params) do
    current_user = socket.assigns.current_user
    logged_in? = !!current_user
    orgs = current_user && Orgs.list_orgs(current_user)

    case Purchases.claim_purchase(current_user, orgs, params["sale_id"], params["token"]) do
      {:already_claimed, sale} ->
        socket
        |> put_flash(
          :info,
          "Congratulations! You can now download #{sale.product.name} using the instructions below."
        )
        |> redirect(to: Routes.purchase_show_path(socket, :show, sale.buyer, sale))

      {:ok, sale} when logged_in? ->
        assign(socket, action: :assign, sale: sale, page_title: page_title(sale), orgs: orgs)

      {:ok, sale} ->
        assign(socket, action: :register, sale: sale, page_title: page_title(sale))

      {:error, message} ->
        socket
        |> put_flash(:error, message)
        |> redirect(to: redirect_to(socket))
    end
  end

  defp page_title(sale), do: "Register #{sale.product.name}"

  defp redirect_to(%{assigns: %{current_user: %{}}} = conn),
    do: Routes.dashboard_index_path(conn, :index)

  defp redirect_to(%{assigns: %{current_user: nil}} = conn),
    do: Routes.user_session_path(conn, :new)
end
