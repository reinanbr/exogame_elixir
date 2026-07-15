defmodule BackendElixir.IdGenerator do
  @moduledoc """
  Random id generation shared across the app. Game ids and player ids use
  different lengths/casing on purpose (game ids are short enough for players
  to type into a "join game" field; player ids are internal only) — they're
  co-located here as the same `strong_rand_bytes |> Base.encode16` pattern,
  not unified into one function.
  """

  @doc "6-character uppercase hex game code, e.g. \"3F9A1C\"."
  def generate_game_id do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16()
    |> binary_part(0, 6)
  end

  @doc "16-character lowercase hex player id."
  def generate_player_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end
end
