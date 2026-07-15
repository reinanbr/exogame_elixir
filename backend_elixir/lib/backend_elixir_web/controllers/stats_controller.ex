defmodule BackendElixirWeb.StatsController do
  use BackendElixirWeb, :controller

  alias BackendElixir.Game.Server, as: GameServer

  @doc "Aggregate stats — how many games are active, and how many players are in them — for the home screen's connection widget."
  def index(conn, _params) do
    stats = GameServer.get_stats()
    json(conn, %{activeGames: stats.active_games, activePlayers: stats.active_players})
  end
end
