defmodule BackendElixirWeb.Router do
  use BackendElixirWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BackendElixirWeb do
    pipe_through :api

    get "/games/:id", GameController, :show
    get "/games/:id/leaderboard", GameController, :leaderboard
    get "/games/:id/current-question", GameController, :current_question

    get "/questions", QuestionController, :index
    get "/questions/random", QuestionController, :random

    get "/stats", StatsController, :index
  end
end
