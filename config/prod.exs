import Config

config :bytepack_web, BytepackWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto]],
  url: [scheme: "https", host: "your-host.sample.com", port: 443],
  server: true

config :logger, level: :info

config :swoosh, local: false
