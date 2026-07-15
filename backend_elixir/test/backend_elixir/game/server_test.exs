defmodule BackendElixir.Game.ServerTest do
  # Game.Server is a singleton process shared by the whole app (started once
  # by the Application supervisor), so tests run synchronously and each uses
  # its own unique host/player ids to stay isolated from one another.
  use ExUnit.Case, async: false

  alias BackendElixir.Game.Server

  defp unique_id(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp create_and_join(host_name \\ "Host", player_name \\ "Player") do
    host_id = unique_id("host")
    {:ok, game} = Server.create_game(host_id, host_name)
    player_id = unique_id("player")
    {:ok, game, _player} = Server.join_game(game.id, player_id, player_name)
    %{host_id: host_id, player_id: player_id, game: game}
  end

  defp wrong_answer_index(question) do
    rem(question.correctAnswer + 1, length(question.options))
  end

  describe "create_game/3" do
    test "returns a game with a 6-character uppercase hex id and a lone host player" do
      host_id = unique_id("host")

      assert {:ok, game} = Server.create_game(host_id, "Solo Host")
      assert game.id =~ ~r/^[0-9A-F]{6}$/
      assert game.hostId == host_id
      assert game.status == :waiting
      assert [%{isHost: true, name: "Solo Host"}] = game.players
    end
  end

  describe "join_game/4" do
    test "succeeds while the game is waiting, adding the player" do
      host_id = unique_id("host")
      {:ok, game} = Server.create_game(host_id, "Host")

      assert {:ok, updated_game, player} =
               Server.join_game(game.id, unique_id("player"), "Guest")

      assert length(updated_game.players) == 2
      assert player.name == "Guest"
      assert player.isHost == false
    end

    test "fails with :game_not_found for a nonexistent game id" do
      assert {:error, :game_not_found} = Server.join_game("ZZZZZZ", unique_id("player"), "Guest")
    end

    test "fails with :already_started once the game has already started" do
      %{host_id: host_id, game: game} = create_and_join()
      {:ok, _} = Server.start_game(game.id, host_id)

      # These two failure modes used to collapse into the same generic
      # :not_found — now distinguishable, so the channel/frontend can show a
      # more accurate message for each.
      assert {:error, :already_started} = Server.join_game(game.id, unique_id("late"), "Late")
    end
  end

  describe "game status transitions" do
    test "moves waiting -> playing -> finished, exposed as atoms internally" do
      %{host_id: host_id, game: game} = create_and_join()
      assert game.status == :waiting

      {:ok, playing} = Server.start_game(game.id, host_id)
      assert playing.status == :playing

      # advance through every question to reach the end of the game
      final =
        Enum.reduce(playing.questions, playing, fn _question, _acc ->
          {:ok, advanced} = Server.next_question(game.id, host_id)
          advanced
        end)

      assert final.status == :finished
    end
  end

  describe "get_stats/0" do
    # Game.Server is a shared singleton across the whole suite, so this
    # asserts relative deltas rather than absolute counts — other tests'
    # leftover non-finished games shouldn't make this flaky.
    test "counts non-finished games/players, and excludes a game once it finishes" do
      before_stats = Server.get_stats()

      %{host_id: host_id, game: game} = create_and_join()
      after_join_stats = Server.get_stats()

      assert after_join_stats.active_games == before_stats.active_games + 1
      assert after_join_stats.active_players == before_stats.active_players + 2

      {:ok, playing} = Server.start_game(game.id, host_id)

      final =
        Enum.reduce(playing.questions, playing, fn _question, _acc ->
          {:ok, advanced} = Server.next_question(game.id, host_id)
          advanced
        end)

      assert final.status == :finished

      after_finish_stats = Server.get_stats()
      assert after_finish_stats.active_games == before_stats.active_games
      assert after_finish_stats.active_players == before_stats.active_players
    end
  end

  describe "leave_game/2" do
    test "removes the player from the game's player list" do
      %{player_id: player_id, game: game} = create_and_join()

      assert :ok = Server.leave_game(game.id, player_id)

      updated = Server.get_game(game.id)
      refute Enum.any?(updated.players, &(&1.id == player_id))
    end

    test "marks the game :finished once its last player leaves" do
      host_id = unique_id("host")
      {:ok, game} = Server.create_game(host_id, "Solo Host")

      assert :ok = Server.leave_game(game.id, host_id)

      updated = Server.get_game(game.id)
      assert updated.status == :finished
    end

    test "decreases active_players (and active_games, if it was the last player) in get_stats/0" do
      %{host_id: host_id, player_id: player_id, game: game} = create_and_join()
      before_stats = Server.get_stats()

      assert :ok = Server.leave_game(game.id, player_id)
      after_one_leaves = Server.get_stats()
      assert after_one_leaves.active_players == before_stats.active_players - 1
      assert after_one_leaves.active_games == before_stats.active_games

      assert :ok = Server.leave_game(game.id, host_id)
      after_both_leave = Server.get_stats()
      assert after_both_leave.active_players == before_stats.active_players - 2
      assert after_both_leave.active_games == before_stats.active_games - 1
    end

    test "is a no-op for a nonexistent game" do
      assert :ok = Server.leave_game("ZZZZZZ", unique_id("player"))
    end
  end

  describe "host-only authorization" do
    test "start_game/2, next_question/2, and show_results/2 all reject a non-host the same way" do
      %{host_id: host_id, game: game} = create_and_join()
      impostor_id = unique_id("impostor")

      assert {:error, _} = Server.start_game(game.id, impostor_id)

      {:ok, _} = Server.start_game(game.id, host_id)
      assert {:error, _} = Server.next_question(game.id, impostor_id)
      assert {:error, _} = Server.show_results(game.id, impostor_id)

      # the real host can still perform all three
      assert :ok = Server.show_results(game.id, host_id)
      assert {:ok, _} = Server.next_question(game.id, host_id)
    end
  end

  describe "submit_answer/4 scoring" do
    # Each game's questions are dealt via Question.get_random/1, which shuffles
    # across the full question bank — and time_limit isn't uniform across
    # questions (most are 20s, a couple are 25s). So these assertions are
    # computed against each game's OWN question.timeLimit rather than as a
    # hardcoded constant or a comparison across two different games' scores,
    # which would be flaky whenever the two games happen to deal questions
    # with different time limits.
    test "awards ~base + full time-bonus for answering almost immediately" do
      %{host_id: host_id, game: game} = create_and_join()
      {:ok, _started} = Server.start_game(game.id, host_id)
      question = Server.get_current_question(game.id)

      {:ok, fast_result} =
        Server.submit_answer(game.id, host_id, question.id, question.correctAnswer)

      fast_score = Enum.find(fast_result.players, &(&1.id == host_id)).score
      expected = 1000 + question.timeLimit * 10

      assert_in_delta fast_score, expected, 15
    end

    test "awards fewer points the longer a player takes to answer correctly" do
      %{host_id: host_id, game: game} = create_and_join()
      {:ok, _} = Server.start_game(game.id, host_id)
      question = Server.get_current_question(game.id)
      :timer.sleep(1100)

      {:ok, slow_result} =
        Server.submit_answer(game.id, host_id, question.id, question.correctAnswer)

      slow_score = Enum.find(slow_result.players, &(&1.id == host_id)).score
      # ~1s elapsed costs ~10 points (time_bonus_multiplier), against this
      # same question's own full-time-bonus baseline.
      expected = 1000 + question.timeLimit * 10 - 10

      assert_in_delta slow_score, expected, 15
    end

    test "awards zero extra points for a wrong answer" do
      %{host_id: host_id, game: game} = create_and_join()
      {:ok, _} = Server.start_game(game.id, host_id)
      question = Server.get_current_question(game.id)

      {:ok, result} =
        Server.submit_answer(game.id, host_id, question.id, wrong_answer_index(question))

      score = Enum.find(result.players, &(&1.id == host_id)).score
      assert score == 0
    end

    test "rejects a second answer from the same player for the same question" do
      %{host_id: host_id, game: game} = create_and_join()
      {:ok, _} = Server.start_game(game.id, host_id)
      question = Server.get_current_question(game.id)

      assert {:ok, _} = Server.submit_answer(game.id, host_id, question.id, question.correctAnswer)

      assert {:error, :already_answered} =
               Server.submit_answer(game.id, host_id, question.id, question.correctAnswer)
    end
  end

  describe "get_leaderboard/1" do
    test "returns players sorted by score descending" do
      %{host_id: host_id, player_id: player_id, game: game} = create_and_join()
      {:ok, _} = Server.start_game(game.id, host_id)
      question = Server.get_current_question(game.id)

      {:ok, _} = Server.submit_answer(game.id, host_id, question.id, question.correctAnswer)
      {:ok, _} = Server.submit_answer(game.id, player_id, question.id, wrong_answer_index(question))

      [first, second] = Server.get_leaderboard(game.id)
      assert first.id == host_id
      assert second.id == player_id
      assert first.score >= second.score
    end
  end

  describe "get_answer_stats/2" do
    test "tracks total/answered/pending as players submit answers" do
      %{host_id: host_id, player_id: player_id, game: game} = create_and_join()
      {:ok, _} = Server.start_game(game.id, host_id)
      question = Server.get_current_question(game.id)

      assert Server.get_answer_stats(game.id, question.id) ==
               %{total: 2, answered: 0, pending: 2}

      {:ok, _} = Server.submit_answer(game.id, host_id, question.id, question.correctAnswer)

      assert Server.get_answer_stats(game.id, question.id) ==
               %{total: 2, answered: 1, pending: 1}

      {:ok, _} =
        Server.submit_answer(game.id, player_id, question.id, wrong_answer_index(question))

      assert Server.get_answer_stats(game.id, question.id) ==
               %{total: 2, answered: 2, pending: 0}
    end
  end

  describe "questionResults broadcast: host-triggered vs timer-triggered" do
    test "both paths broadcast the same shape of payload" do
      # Host-triggered path: Server.show_results/2 (called by the channel's
      # "showResults" event).
      %{host_id: host_id, game: game} = create_and_join()
      {:ok, _} = Server.start_game(game.id, host_id)
      Phoenix.PubSub.subscribe(BackendElixir.PubSub, "game:#{game.id}")

      assert :ok = Server.show_results(game.id, host_id)

      assert_receive %Phoenix.Socket.Broadcast{
                        topic: topic1,
                        event: "questionResults",
                        payload: host_payload
                      },
                      1000

      assert topic1 == "game:#{game.id}"

      # Timer-triggered path: send the exact message the real per-question
      # timer sends on expiry (see Game.Server's handle_info/2), instead of
      # waiting out a real 20+ second timer.
      %{host_id: host_id2, game: game2} = create_and_join()
      {:ok, _} = Server.start_game(game2.id, host_id2)
      question2 = Server.get_current_question(game2.id)
      Phoenix.PubSub.subscribe(BackendElixir.PubSub, "game:#{game2.id}")

      send(Process.whereis(Server), {:auto_show_results, game2.id, question2.id})

      assert_receive %Phoenix.Socket.Broadcast{
                        topic: topic2,
                        event: "questionResults",
                        payload: timer_payload
                      },
                      1000

      assert topic2 == "game:#{game2.id}"

      # Same payload shape from both trigger paths.
      assert Map.keys(host_payload) |> Enum.sort() == Map.keys(timer_payload) |> Enum.sort()
      assert Map.keys(host_payload.question) |> Enum.sort() ==
               Map.keys(timer_payload.question) |> Enum.sort()

      assert is_list(host_payload.leaderboard)
      assert is_list(timer_payload.leaderboard)
    end
  end
end
