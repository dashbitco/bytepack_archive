defmodule BytepackWeb.OAuthController do
  use BytepackWeb, :controller

  def stripe(conn, params) do
    case Bytepack.Stripe.oauth_callback(params) do
      {:ok, seller} ->
        conn
        |> put_flash(:info, "Successfully connected to your Stripe account.")
        |> redirect(to: Routes.org_edit_path(conn, :edit, seller))

      :error ->
        conn
        |> put_flash(:error, "Could not complete Stripe authentication, please try again.")
        |> redirect(to: Routes.dashboard_index_path(conn, :index))
    end
  end
end
