defmodule BackendElixir.Game.Player do
  @moduledoc """
  Player utilities for the game.
  """

  @avatars [
    "🐻", "🐱", "🐶", "🐺", "🦊", "🐨", "🐼", "🐸",
    "🦁", "🐯", "🐮", "🐷", "🐵", "🐰", "🐹",
    "🦄", "🐴", "🐗", "🐭", "🐳", "🐙", "🦀", "🐢",
    "🦅", "🐧", "🐔", "🦆", "🦉", "🦇", "🦋", "🐝"
  ]

  @type t :: %{
          id: String.t(),
          name: String.t(),
          score: non_neg_integer(),
          is_host: boolean(),
          avatar: String.t()
        }

  @doc "Builds a new player record with score 0, picking a random avatar if none is given."
  @spec new(String.t(), String.t(), boolean(), String.t() | nil) :: t()
  def new(id, name, is_host \\ false, avatar \\ nil) do
    %{
      id: id,
      name: name,
      score: 0,
      is_host: is_host,
      avatar: avatar || random_avatar()
    }
  end

  @doc "The fixed list of avatar emoji players can choose from."
  @spec available_avatars() :: [String.t()]
  def available_avatars, do: @avatars

  defp random_avatar do
    Enum.random(@avatars)
  end
end
