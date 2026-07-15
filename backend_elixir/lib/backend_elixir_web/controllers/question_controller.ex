defmodule BackendElixirWeb.QuestionController do
  use BackendElixirWeb, :controller

  alias BackendElixir.Game.Question

  def index(conn, _params) do
    questions =
      Question.all_questions()
      |> Enum.map(&Question.serialize/1)

    json(conn, questions)
  end

  def random(conn, _params) do
    questions =
      Question.get_random()
      |> Enum.map(&Question.serialize/1)

    json(conn, questions)
  end
end
