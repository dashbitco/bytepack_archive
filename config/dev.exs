import Config

# Configure your database
config :bytepack, Bytepack.Repo,
  username: "postgres",
  password: "postgres",
  database: "bytepack_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :bytepack, Bytepack.Mailer, adapter: Swoosh.Adapters.Local

config :bytepack, :packages_store, api: Bytepack.Packages.Store.Local

config :bytepack, :dev_store, port: 4003

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :bytepack_web, BytepackWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../apps/bytepack_web/assets", __DIR__)
    ]
  ]

# Watch static and templates for browser reloading.
config :bytepack_web, BytepackWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/bytepack_web/(live|views)/.*(ex)$",
      ~r"lib/bytepack_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20
