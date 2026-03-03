defmodule BackendElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BackendElixirWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:backend_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BackendElixir.PubSub},
      # Game state server
      BackendElixir.Game.Server,
      # Start to serve requests, typically the last entry
      BackendElixirWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BackendElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BackendElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
