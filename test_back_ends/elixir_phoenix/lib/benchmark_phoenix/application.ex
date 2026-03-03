defmodule BenchmarkPhoenix.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: BenchmarkPhoenix.PubSub},
      BenchmarkPhoenix.Repo,
      BenchmarkPhoenixWeb.Endpoint
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: BenchmarkPhoenix.Supervisor)
  end
end
