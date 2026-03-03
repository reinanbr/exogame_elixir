defmodule BackendElixirWeb.QuestionController do
  use BackendElixirWeb, :controller

  alias BackendElixir.Game.Question

  def index(conn, _params) do
    questions =
      Question.all_questions()
      |> Enum.map(&serialize_question/1)

    json(conn, questions)
  end

  def random(conn, _params) do
    questions =
      Question.get_random()
      |> Enum.map(&serialize_question/1)

    json(conn, questions)
  end

  defp serialize_question(q) do
    %{
      id: q.id,
      text: q.text,
      options: q.options,
      correctAnswer: q.correct_answer,
      correctAnswerContext: q.correct_answer_context,
      timeLimit: q.time_limit
    }
  end
end
