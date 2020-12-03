defmodule BytepackWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :bytepack_web

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_bytepack_web_key",
    signing_salt: "1jzV3AoQ"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    longpoll: [connect_info: [:x_headers, :user_agent, session: @session_options]],
    websocket: [connect_info: [:x_headers, :user_agent, session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :bytepack_web,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :bytepack_web
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug :redirect_away_from_www
  plug :parse_body

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug BytepackWeb.Router

  ## Parsing helpers

  opts = [
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    body_reader: {BytepackWeb.Extensions.Plug.BodyReader, :cache_raw_body, []}
  ]

  @parser_without_cache Plug.Parsers.init(Keyword.delete(opts, :body_reader))
  @parser_with_cache Plug.Parsers.init(opts)

  # All endpoints that start with "webhooks" have their body cached.
  defp parse_body(%{path_info: ["webhooks" | _]} = conn, _),
    do: Plug.Parsers.call(conn, @parser_with_cache)

  defp parse_body(conn, _),
    do: Plug.Parsers.call(conn, @parser_without_cache)

  ## Host helpers

  defp redirect_away_from_www(%{host: "www.bytepack.io"} = conn, _opts) do
    uri = %{
      struct_url()
      | host: "bytepack.io",
        path: conn.request_path,
        query: nillify(conn.query_string)
    }

    conn
    |> Phoenix.Controller.redirect(external: URI.to_string(uri))
    |> halt()
  end

  defp redirect_away_from_www(conn, _opts) do
    conn
  end

  defp nillify(""), do: nil
  defp nillify(bin), do: bin
end
