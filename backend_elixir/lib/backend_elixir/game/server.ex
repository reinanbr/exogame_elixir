defmodule BackendElixir.Game.Server do
  @moduledoc """
  GenServer that manages game state in-memory.
  Replaces the NestJS GameService + PlayerService.
  """
  use GenServer

  alias BackendElixir.Game.{Player, Question}

  # ------- Public API -------

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def create_game(host_id, host_name, avatar \\ nil) do
    GenServer.call(__MODULE__, {:create_game, host_id, host_name, avatar})
  end

  def join_game(game_id, player_id, player_name, avatar \\ nil) do
    GenServer.call(__MODULE__, {:join_game, game_id, player_id, player_name, avatar})
  end

  def start_game(game_id, host_id) do
    GenServer.call(__MODULE__, {:start_game, game_id, host_id})
  end

  def next_question(game_id, host_id) do
    GenServer.call(__MODULE__, {:next_question, game_id, host_id})
  end

  def submit_answer(game_id, player_id, question_id, answer) do
    GenServer.call(__MODULE__, {:submit_answer, game_id, player_id, question_id, answer})
  end

  def get_game(game_id) do
    GenServer.call(__MODULE__, {:get_game, game_id})
  end

  def get_current_question(game_id) do
    GenServer.call(__MODULE__, {:get_current_question, game_id})
  end

  def get_leaderboard(game_id) do
    GenServer.call(__MODULE__, {:get_leaderboard, game_id})
  end

  def get_answer_stats(game_id, question_id) do
    GenServer.call(__MODULE__, {:get_answer_stats, game_id, question_id})
  end

  def get_available_avatars do
    Player.available_avatars()
  end

  # ------- Callbacks -------

  @impl true
  def init(_) do
    {:ok, %{games: %{}, answers: %{}}}
  end

  @impl true
  def handle_call({:create_game, host_id, host_name, avatar}, _from, state) do
    game_id = generate_game_id()
    host = Player.new(host_id, host_name, true, avatar)
    questions = Question.get_random(5)

    game = %{
      id: game_id,
      host_id: host_id,
      players: [host],
      questions: questions,
      current_question_index: -1,
      status: "waiting",
      current_question_start_time: nil
    }

    new_state =
      state
      |> put_in([:games, game_id], game)
      |> put_in([:answers, game_id], [])

    {:reply, {:ok, serialize_game(game)}, new_state}
  end

  def handle_call({:join_game, game_id, player_id, player_name, avatar}, _from, state) do
    case get_in(state, [:games, game_id]) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: status} when status != "waiting" ->
        {:reply, {:error, :not_found}, state}

      game ->
        player = Player.new(player_id, player_name, false, avatar)
        updated_game = %{game | players: game.players ++ [player]}

        new_state = put_in(state, [:games, game_id], updated_game)
        {:reply, {:ok, serialize_game(updated_game), serialize_player(player)}, new_state}
    end
  end

  def handle_call({:start_game, game_id, host_id}, _from, state) do
    case get_in(state, [:games, game_id]) do
      %{host_id: ^host_id, status: "waiting"} = game ->
        now = DateTime.utc_now() |> DateTime.to_iso8601()

        updated_game = %{
          game
          | status: "playing",
            current_question_index: 0,
            current_question_start_time: now
        }

        new_state = put_in(state, [:games, game_id], updated_game)
        {:reply, {:ok, serialize_game(updated_game)}, new_state}

      _ ->
        {:reply, {:error, :cannot_start}, state}
    end
  end

  def handle_call({:next_question, game_id, host_id}, _from, state) do
    case get_in(state, [:games, game_id]) do
      %{host_id: ^host_id, status: "playing"} = game ->
        next_index = game.current_question_index + 1

        updated_game =
          if next_index >= length(game.questions) do
            %{game | status: "finished", current_question_index: next_index}
          else
            now = DateTime.utc_now() |> DateTime.to_iso8601()
            %{game | current_question_index: next_index, current_question_start_time: now}
          end

        new_state = put_in(state, [:games, game_id], updated_game)
        {:reply, {:ok, serialize_game(updated_game)}, new_state}

      _ ->
        {:reply, {:error, :cannot_advance}, state}
    end
  end

  def handle_call({:submit_answer, game_id, player_id, question_id, answer}, _from, state) do
    game = get_in(state, [:games, game_id])

    cond do
      is_nil(game) or game.status != "playing" ->
        {:reply, {:error, :invalid_game}, state}

      true ->
        current_q = Enum.at(game.questions, game.current_question_index)

        cond do
          is_nil(current_q) or current_q.id != question_id ->
            {:reply, {:error, :invalid_question}, state}

          true ->
            game_answers = get_in(state, [:answers, game_id]) || []

            already_answered =
              Enum.any?(game_answers, fn a ->
                a.player_id == player_id and a.question_id == question_id
              end)

            if already_answered do
              {:reply, {:error, :already_answered}, state}
            else
              player_answer = %{
                player_id: player_id,
                question_id: question_id,
                answer: answer,
                answered_at: DateTime.utc_now()
              }

              new_answers = game_answers ++ [player_answer]

              # Calculate score if correct
              updated_game =
                if answer == current_q.correct_answer do
                  start_time = game.current_question_start_time
                  time_taken = calc_time_taken(start_time)
                  time_bonus = max(0, current_q.time_limit - time_taken)
                  points = round(1000 + time_bonus * 10)

                  updated_players =
                    Enum.map(game.players, fn p ->
                      if p.id == player_id do
                        %{p | score: p.score + points}
                      else
                        p
                      end
                    end)

                  %{game | players: updated_players}
                else
                  game
                end

              new_state =
                state
                |> put_in([:games, game_id], updated_game)
                |> put_in([:answers, game_id], new_answers)

              {:reply, {:ok, serialize_game(updated_game)}, new_state}
            end
        end
    end
  end

  def handle_call({:get_game, game_id}, _from, state) do
    case get_in(state, [:games, game_id]) do
      nil -> {:reply, nil, state}
      game -> {:reply, serialize_game(game), state}
    end
  end

  def handle_call({:get_current_question, game_id}, _from, state) do
    game = get_in(state, [:games, game_id])

    result =
      if game && game.current_question_index >= 0 &&
           game.current_question_index < length(game.questions) do
        q = Enum.at(game.questions, game.current_question_index)
        serialize_question(q)
      else
        nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_leaderboard, game_id}, _from, state) do
    game = get_in(state, [:games, game_id])

    result =
      if game do
        game.players
        |> Enum.sort_by(& &1.score, :desc)
        |> Enum.map(&serialize_player/1)
      else
        []
      end

    {:reply, result, state}
  end

  def handle_call({:get_answer_stats, game_id, question_id}, _from, state) do
    game = get_in(state, [:games, game_id])
    game_answers = get_in(state, [:answers, game_id]) || []

    result =
      if game do
        answered_count =
          Enum.count(game_answers, fn a -> a.question_id == question_id end)

        total = length(game.players)

        %{
          total: total,
          answered: answered_count,
          pending: total - answered_count
        }
      else
        %{total: 0, answered: 0, pending: 0}
      end

    {:reply, result, state}
  end

  # ------- Private helpers -------

  defp generate_game_id do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16()
    |> binary_part(0, 6)
  end

  defp calc_time_taken(start_time_iso) when is_binary(start_time_iso) do
    case DateTime.from_iso8601(start_time_iso) do
      {:ok, start_dt, _} ->
        DateTime.diff(DateTime.utc_now(), start_dt, :millisecond) / 1000

      _ ->
        0
    end
  end

  defp calc_time_taken(_), do: 0

  # Serialize game to camelCase JSON-friendly map (matches frontend expectations)
  defp serialize_game(game) do
    %{
      id: game.id,
      hostId: game.host_id,
      players: Enum.map(game.players, &serialize_player/1),
      questions: Enum.map(game.questions, &serialize_question/1),
      currentQuestionIndex: game.current_question_index,
      status: game.status,
      currentQuestionStartTime: game.current_question_start_time
    }
  end

  defp serialize_player(player) do
    %{
      id: player.id,
      name: player.name,
      score: player.score,
      isHost: player.is_host,
      avatar: player.avatar
    }
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
