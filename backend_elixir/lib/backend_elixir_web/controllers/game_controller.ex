defmodule BackendElixirWeb.GameController do
  use BackendElixirWeb, :controller

  alias BackendElixir.Game.Server, as: GameServer
  alias BackendElixir.Game.Question

  def show(conn, %{"id" => id}) do
    case GameServer.get_game(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Jogo não encontrado"})

      game ->
        json(conn, game)
    end
  end

  def leaderboard(conn, %{"id" => id}) do
    leaderboard = GameServer.get_leaderboard(id)
    json(conn, leaderboard)
  end

  def current_question(conn, %{"id" => id}) do
    case GameServer.get_current_question(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pergunta não encontrada"})

      question ->
        json(conn, Question.strip_answer(question))
    end
  end
end
