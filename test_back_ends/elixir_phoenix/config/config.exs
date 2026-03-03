import Config

config :benchmark_phoenix, BenchmarkPhoenixWeb.Endpoint,
  url: [host: "0.0.0.0"],
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {0, 0, 0, 0}, port: 8080],
  check_origin: false,
  pubsub_server: BenchmarkPhoenix.PubSub,
  server: true

config :benchmark_phoenix, BenchmarkPhoenix.Repo,
  hostname: System.get_env("DB_HOST") || "postgres",
  port: 5432,
  database: "bench",
  username: "bench",
  password: "bench",
  pool_size: 50

config :phoenix, :json_library, Jason
config :logger, level: :warning
