defmodule BytepackWeb.Hex.Auth do
  import Plug.Conn
  alias Bytepack.{Accounts, Hex, Orgs}

  def init(domain), do: domain

  def call(conn, domain) do
    org = Orgs.get_org!(conn.params["org_slug"])

    token =
      case Plug.Conn.get_req_header(conn, "authorization") do
        [token | _] -> token
        [] -> nil
      end

    membership = token && get_membership(domain, org, token)

    if membership do
      conn
      |> assign(:current_org, org)
      |> assign(:current_membership, membership)
      |> assign(:current_user, Accounts.get_user!(membership.member_id))
      |> assign(:registry, Hex.ensure_registry!(org))
    else
      conn
      |> send_resp(401, "Unauthenticated")
      |> halt()
    end
  end

  defp get_membership(:api, org, token) do
    org.is_seller && Orgs.get_membership_by_org_and_write_token(org, token)
  end

  defp get_membership(:repo, org, token) do
    Orgs.get_membership_by_org_and_read_token(org, token)
  end
end
