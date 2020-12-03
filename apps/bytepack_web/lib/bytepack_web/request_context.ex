defmodule BytepackWeb.RequestContext do
  alias Bytepack.AuditLog

  def put_audit_context(conn_or_socket, opts \\ [])

  def put_audit_context(%Plug.Conn{} = conn, _) do
    user_agent =
      case List.keyfind(conn.req_headers, "user-agent", 0) do
        {_, value} -> value
        _ -> nil
      end

    Plug.Conn.assign(conn, :audit_context, %AuditLog{
      user_agent: user_agent,
      ip_address: get_ip(conn.req_headers),
      user: conn.assigns[:current_user],
      org: conn.assigns[:current_org]
    })
  end

  def put_audit_context(%Phoenix.LiveView.Socket{} = socket, _) do
    audit_context = %AuditLog{
      user: socket.assigns[:current_user],
      org: socket.assigns[:current_org]
    }

    extra =
      if info = Phoenix.LiveView.get_connect_info(socket) do
        ip = get_ip(info[:x_headers] || [])
        %{ip_address: ip, user_agent: info[:user_agent]}
      else
        %{}
      end

    Phoenix.LiveView.assign(socket, :audit_context, struct!(audit_context, extra))
  end

  defp get_ip(headers) do
    with {_, ip} <- List.keyfind(headers, "x-forwarded-for", 0),
         [ip | _] = String.split(ip, ","),
         {:ok, address} <- Bytepack.Extensions.Ecto.IPAddress.cast(ip) do
      address
    else
      _ ->
        nil
    end
  end

  def put_sentry_context(conn_or_socket, _opts \\ []) do
    conn_or_socket
    |> put_request_context()
    |> put_user_context()
  end

  defp put_request_context(%Plug.Conn{} = conn) do
    Sentry.Context.set_request_context(%{
      url: Plug.Conn.request_url(conn),
      method: conn.method,
      headers: %{
        "User-Agent": Plug.Conn.get_req_header(conn, "user-agent") |> List.first()
      },
      query_string: conn.query_string,
      env: %{
        REQUEST_ID: Plug.Conn.get_resp_header(conn, "x-request-id") |> List.first(),
        SERVER_NAME: conn.host
      }
    })

    conn
  end

  defp put_request_context(%Phoenix.LiveView.Socket{} = socket) do
    request_context = %{
      host: socket.host_uri.host
    }

    extras =
      if info = Phoenix.LiveView.get_connect_info(socket) do
        request_id = Phoenix.LiveView.get_connect_params(socket)["_request_id"]

        %{
          headers: %{
            "User-Agent": info[:user_agent]
          },
          env: %{
            REQUEST_ID: request_id
          }
        }
      else
        %{}
      end

    Sentry.Context.set_request_context(Map.merge(request_context, extras))
    socket
  end

  defp put_user_context(conn_or_socket) do
    user = conn_or_socket.assigns[:current_user]
    org = conn_or_socket.assigns[:current_org]

    if user do
      Sentry.Context.set_user_context(%{
        id: user.id,
        username: "User #{user.id}",
        org_id: org && org.id
      })
    end

    conn_or_socket
  end
end
