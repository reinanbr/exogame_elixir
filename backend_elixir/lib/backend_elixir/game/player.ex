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

  def new(id, name, is_host \\ false, avatar \\ nil) do
    %{
      id: id,
      name: name,
      score: 0,
      is_host: is_host,
      avatar: avatar || random_avatar()
    }
  end

  def available_avatars, do: @avatars

  defp random_avatar do
    Enum.random(@avatars)
  end
end
