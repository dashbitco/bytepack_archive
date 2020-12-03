defmodule BytepackWeb.Hex.RepoController do
  use BytepackWeb, :controller
  alias Bytepack.{Hex, Packages, Purchases}

  def repo_index(conn, _) do
    text(conn, "")
  end

  def get_names(conn, _) do
    registry = conn.assigns.registry
    packages = list_available_packages(conn)
    encoded = Hex.build_names(registry, packages)
    send_resp(conn, 200, encoded)
  end

  def get_versions(conn, _) do
    registry = conn.assigns.registry

    packages =
      conn
      |> list_available_packages()
      |> Packages.preload_releases()

    encoded = Hex.build_versions(registry, packages)
    send_resp(conn, 200, encoded)
  end

  def get_package(conn, %{"name" => name}) do
    registry = conn.assigns.registry
    package = get_package!(conn, name)
    encoded = Hex.build_package(registry, package)

    hash =
      encoded
      |> :erlang.term_to_binary()
      |> :erlang.md5()

    with_etag_cache(conn, hash, fn conn ->
      send_resp(conn, 200, encoded)
    end)
  end

  def get_tarball(conn, %{"basename" => [basename]}) do
    {:ok, name, version} = extract_name_version(basename)
    package = get_package!(conn, name)
    hex_release = Hex.get_hex_release!(package, version)

    with_etag_cache(conn, hex_release.outer_checksum, fn outer_conn ->
      request = Hex.get_tarball_request(package, version)

      fun = fn
        {:status, status}, conn ->
          Plug.Conn.send_chunked(conn, status)

        {:headers, _headers}, conn ->
          conn

        {:data, chunk}, conn ->
          {:ok, conn} = Plug.Conn.chunk(conn, chunk)
          conn
      end

      {:ok, conn} = Finch.stream(request, Bytepack.Finch, outer_conn, fun)

      Packages.increment_download_counter!(hex_release.release, conn.assigns.current_membership)

      conn
    end)
  end

  defp extract_name_version(basename) do
    with [name, version, ""] <- String.split(basename, ["-", ".tar"]),
         true <- name == Path.basename(name),
         {:ok, _} <- Version.parse(version) do
      {:ok, name, version}
    else
      _ -> :error
    end
  end

  def public_key(conn, _) do
    org = conn.assigns.current_org
    registry = Hex.get_registry_by_org!(org)
    send_resp(conn, 200, registry.public_key)
  end

  defp list_available_packages(conn) do
    case conn.assigns.hex_context do
      :repo -> Purchases.list_available_packages(conn.assigns.current_org, type: "hex")
      :test_repo -> Packages.list_available_packages(conn.assigns.current_org, type: "hex")
    end
  end

  defp get_package!(conn, name) do
    case conn.assigns.hex_context do
      :repo ->
        Purchases.get_available_package_by!(conn.assigns.current_org, type: "hex", name: name)

      :test_repo ->
        Packages.get_available_package_by!(conn.assigns.current_org, type: "hex", name: name)
    end
  end

  defp with_etag_cache(conn, hash, fun) do
    etag = ~s{"#{Base.url_encode64(hash, case: :lower, padding: false)}"}

    if etag in get_req_header(conn, "if-none-match") do
      conn
      |> send_resp(304, "")
      |> halt()
    else
      fun.(put_resp_header(conn, "etag", etag))
    end
  end
end
