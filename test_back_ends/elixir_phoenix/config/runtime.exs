import Config

config :benchmark_phoenix, BenchmarkPhoenix.Repo,
  hostname: System.get_env("DB_HOST") || "postgres"
