defmodule BackendElixir.Game.Question do
  @moduledoc """
  Question data and utilities for the game.
  """

  @type t :: %{
          id: String.t(),
          text: String.t(),
          options: [String.t()],
          correct_answer: non_neg_integer(),
          correct_answer_context: String.t(),
          time_limit: non_neg_integer()
        }

  @questions [
    %{
      id: "1",
      text: "Qual é a capital do Brasil?",
      options: ["São Paulo", "Rio de Janeiro", "Brasília", "Salvador"],
      correct_answer: 2,
      correct_answer_context:
        "Brasília é a capital federal do Brasil desde 1960, quando foi inaugurada para substituir o Rio de Janeiro como sede do governo federal. A cidade foi planejada e construída especificamente para ser a capital.",
      time_limit: 15
    },
    %{
      id: "2",
      text: "Quantos planetas existem no sistema solar?",
      options: ["7", "8", "9", "10"],
      correct_answer: 1,
      correct_answer_context:
        "O sistema solar possui 8 planetas: Mercúrio, Vênus, Terra, Marte, Júpiter, Saturno, Urano e Netuno. Plutão foi reclassificado como planeta anão em 2006 pela União Astronômica Internacional.",
      time_limit: 15
    },
    %{
      id: "3",
      text: "Qual é o maior oceano do mundo?",
      options: ["Atlântico", "Índico", "Ártico", "Pacífico"],
      correct_answer: 3,
      correct_answer_context:
        "O Oceano Pacífico é o maior oceano do mundo, cobrindo aproximadamente 46% da superfície oceânica da Terra e cerca de 32% da superfície total do planeta. Estende-se da Ásia e Austrália até as Américas.",
      time_limit: 15
    },
    %{
      id: "4",
      text: "Em que ano o homem pisou na Lua pela primeira vez?",
      options: ["1967", "1969", "1971", "1973"],
      correct_answer: 1,
      correct_answer_context:
        "Neil Armstrong e Buzz Aldrin foram os primeiros seres humanos a pisar na Lua em 20 de julho de 1969, durante a missão Apollo 11 da NASA. Armstrong foi o primeiro a descer, seguido por Aldrin cerca de 20 minutos depois.",
      time_limit: 20
    },
    %{
      id: "5",
      text: "Qual é o elemento químico representado pelo símbolo \"Au\"?",
      options: ["Prata", "Ouro", "Alumínio", "Arsênio"],
      correct_answer: 1,
      correct_answer_context:
        "O símbolo \"Au\" representa o ouro na tabela periódica. Este símbolo deriva do termo latino \"aurum\", que significa ouro. O ouro é um metal precioso com número atômico 79.",
      time_limit: 15
    }
  ]

  def all_questions, do: @questions

  def get_by_id(id) do
    Enum.find(@questions, fn q -> q.id == id end)
  end

  def get_random(count \\ 5) do
    @questions
    |> Enum.shuffle()
    |> Enum.take(min(count, length(@questions)))
    |> Enum.map(&shuffle_options/1)
  end

  defp shuffle_options(question) do
    correct_text = Enum.at(question.options, question.correct_answer)
    shuffled = Enum.shuffle(question.options)
    new_correct_index = Enum.find_index(shuffled, fn opt -> opt == correct_text end)

    %{question | options: shuffled, correct_answer: new_correct_index}
  end
end
