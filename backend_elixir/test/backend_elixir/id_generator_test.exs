defmodule BackendElixir.IdGeneratorTest do
  use ExUnit.Case, async: true

  alias BackendElixir.IdGenerator

  test "generate_game_id/0 returns a 6-character uppercase hex string" do
    assert IdGenerator.generate_game_id() =~ ~r/^[0-9A-F]{6}$/
  end

  test "generate_player_id/0 returns a 16-character lowercase hex string" do
    assert IdGenerator.generate_player_id() =~ ~r/^[0-9a-f]{16}$/
  end
end
