import Config

config :bytepack, Bytepack.Repo,
  ssl: true,
  url: System.fetch_env!("DATABASE_URL"),
  pool_size: String.to_integer(System.fetch_env!("POOL_SIZE"))

config :bytepack, Bytepack.Mailer,
  adapter: Swoosh.Adapters.Postmark,
  api_key: System.fetch_env!("POSTMARK_API_KEY")

config :bytepack, :stripe,
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  platform_id: System.fetch_env!("STRIPE_PLATFORM_ID"),
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

config :bytepack, :packages_store,
  api: Bytepack.Packages.Store.GCS,
  bucket: System.fetch_env!("BUCKET")

config :bytepack,
  goth_credentials: System.fetch_env!("GOOGLE_APPLICATION_CREDENTIALS_JSON")

config :bytepack_web, BytepackWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

config :libcluster,
  topologies: [
    bytepack: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        kubernetes_selector: System.fetch_env!("LIBCLUSTER_KUBERNETES_SELECTOR"),
        kubernetes_node_basename: System.fetch_env!("LIBCLUSTER_KUBERNETES_NODE_BASENAME")
      ]
    ]
  ]
