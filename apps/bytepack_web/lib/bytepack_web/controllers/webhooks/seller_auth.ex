defmodule BytepackWeb.Webhooks.SellerAuth do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Bytepack.Accounts
  alias Bytepack.Orgs
  alias Bytepack.Sales

  def init(_opts), do: []

  def call(conn, _opts) do
    token =
      with [token | _] <- Plug.Conn.get_req_header(conn, "authorization"),
           "Bearer " <> auth_token <- token do
        auth_token
      else
        _ ->
          nil
      end

    org = Orgs.get_org!(conn.params["org_slug"])
    membership = token && get_membership(org, token)

    if membership do
      conn
      |> assign(:current_org, org)
      |> assign(:current_membership, membership)
      |> assign(:current_user, Accounts.get_user!(membership.member_id))
      |> assign(:current_seller, Sales.get_seller!(org))
    else
      conn
      |> put_status(401)
      |> json(%{"error" => %{"status" => "401", "title" => "Unauthorized"}})
      |> halt()
    end
  end

  defp get_membership(org, token) do
    org.is_seller && Orgs.get_membership_by_org_and_write_token(org, token)
  end
end
