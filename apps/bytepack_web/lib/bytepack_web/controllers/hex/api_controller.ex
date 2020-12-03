defmodule BytepackWeb.Hex.APIController do
  use BytepackWeb, :controller
  alias Bytepack.Hex
  alias BytepackWeb.ErrorHelpers

  def api_index(conn, _) do
    hex_erlang(conn, 200, %{})
  end

  def me(conn, _) do
    hex_erlang(conn, 200, %{"organizations" => []})
  end

  def publish(conn, params) do
    org = conn.assigns.current_org

    {:ok, tarball, conn} = read_tarball(conn)
    opts = [replace: params["replace"] == "true"]

    case Hex.publish(conn.assigns.audit_context, org, tarball, opts) do
      {:ok, operations} ->
        Bytepack.Packages.broadcast_published(
          conn.assigns.current_user.id,
          operations.package,
          operations.release,
          !operations.get_package
        )

        html_url = BytepackWeb.Endpoint.url()

        hex_erlang(conn, 200, %{
          "html_url" => html_url
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        hex_erlang(conn, 422, %{"errors" => ErrorHelpers.error_map_unwrapped(changeset)})

      {:error, reason} ->
        message = reason |> :hex_tarball.format_error() |> List.to_string()
        hex_erlang(conn, 422, %{"errors" => %{"tar" => message}})
    end
  end

  def publish_docs(conn, _) do
    send_resp(conn, 405, "Publishing docs is not yet supported by bytepack.io")
  end

  defp hex_erlang(conn, status, body) do
    conn
    |> put_resp_header("content-type", "application/vnd.hex+erlang")
    |> send_resp(status, :erlang.term_to_binary(body))
  end

  defp read_tarball(conn, tarball \\ <<>>) do
    case Plug.Conn.read_body(conn) do
      {:more, partial, conn} ->
        read_tarball(conn, tarball <> partial)

      {:ok, body, conn} ->
        {:ok, tarball <> body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
