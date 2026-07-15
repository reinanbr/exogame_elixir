defmodule BackendElixir.Game.Server do
  @moduledoc """
  GenServer that manages game state in-memory.
  Replaces the NestJS GameService + PlayerService.
  """
  use GenServer

  alias BackendElixir.Game.{Player, Question}
  alias BackendElixir.IdGenerator
  alias BackendElixirWeb.Endpoint

  # Scoring: base points for a correct answer, plus a per-second bonus for
  # remaining time when the answer was submitted.
  @base_points 1000
  @time_bonus_multiplier 10

  @typedoc "In-memory game record — internal shape, before serialize_game/1 converts it to the camelCase wire format."
  @type game :: %{
          id: String.t(),
          host_id: String.t(),
          players: [Player.t()],
          questions: [Question.t()],
          current_question_index: integer(),
          status: :waiting | :playing | :finished,
          current_question_start_time: String.t() | nil
        }

  @typedoc "GenServer state — four maps all keyed by game_id (see the TODO on init/1 about consolidating these)."
  @type state :: %{
          games: %{optional(String.t()) => game()},
          answers: %{optional(String.t()) => list()},
          question_results_shown: %{optional(String.t()) => MapSet.t()},
          question_timers: %{optional(String.t()) => %{ref: reference(), question_id: String.t()}}
        }

  # ------- Public API -------

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Creates a new game in the `:waiting` status, with `host_name` as its sole (host) player."
  @spec create_game(String.t(), String.t(), String.t() | nil) :: {:ok, map()}
  def create_game(host_id, host_name, avatar \\ nil) do
    GenServer.call(__MODULE__, {:create_game, host_id, host_name, avatar})
  end

  @doc "Adds a player to a `:waiting` game. Fails with `:game_not_found` or `:already_started`."
  @spec join_game(String.t(), String.t(), String.t(), String.t() | nil) ::
          {:ok, map(), map()} | {:error, :game_not_found | :already_started}
  def join_game(game_id, player_id, player_name, avatar \\ nil) do
    GenServer.call(__MODULE__, {:join_game, game_id, player_id, player_name, avatar})
  end

  @doc "Host-only: moves a `:waiting` game to `:playing` and schedules the first question's timer."
  @spec start_game(String.t(), String.t()) :: {:ok, map()} | {:error, :cannot_start}
  def start_game(game_id, host_id) do
    GenServer.call(__MODULE__, {:start_game, game_id, host_id})
  end

  @doc "Host-only: advances to the next question, or to `:finished` if the last question was reached."
  @spec next_question(String.t(), String.t()) :: {:ok, map()} | {:error, :cannot_advance}
  def next_question(game_id, host_id) do
    GenServer.call(__MODULE__, {:next_question, game_id, host_id})
  end

  @doc "Records a player's answer to the current question, scoring it if correct."
  @spec submit_answer(String.t(), String.t(), String.t(), integer()) ::
          {:ok, map()} | {:error, :invalid_game | :invalid_question | :already_answered}
  def submit_answer(game_id, player_id, question_id, answer) do
    GenServer.call(__MODULE__, {:submit_answer, game_id, player_id, question_id, answer})
  end

  @doc """
  Removes a player from a game — called when their channel terminates (tab
  closed, network dropped, etc.), so the "active astronauts" count stays
  accurate. If that was the last player left, the game is marked `:finished`
  (an abandoned room no longer counts as active).
  """
  @spec leave_game(String.t(), String.t()) :: :ok
  def leave_game(game_id, player_id) do
    GenServer.call(__MODULE__, {:leave_game, game_id, player_id})
  end

  @doc "Returns the serialized game, or `nil` if it doesn't exist."
  @spec get_game(String.t()) :: map() | nil
  def get_game(game_id) do
    GenServer.call(__MODULE__, {:get_game, game_id})
  end

  @doc "Returns the serialized current question (including the correct answer — callers strip it before sending to players), or `nil`."
  @spec get_current_question(String.t()) :: map() | nil
  def get_current_question(game_id) do
    GenServer.call(__MODULE__, {:get_current_question, game_id})
  end

  @doc "Returns players sorted by score descending, serialized. Empty list if the game doesn't exist."
  @spec get_leaderboard(String.t()) :: [map()]
  def get_leaderboard(game_id) do
    GenServer.call(__MODULE__, {:get_leaderboard, game_id})
  end

  @doc "Returns `%{total:, answered:, pending:}` for a question's answers so far."
  @spec get_answer_stats(String.t(), String.t()) :: %{
          total: non_neg_integer(),
          answered: non_neg_integer(),
          pending: non_neg_integer()
        }
  def get_answer_stats(game_id, question_id) do
    GenServer.call(__MODULE__, {:get_answer_stats, game_id, question_id})
  end

  @doc """
  Host-triggered "show results now" — reuses the same broadcast path the
  per-question timer uses when it fires automatically (see
  `maybe_broadcast_question_results/3`), so there's one implementation of
  "build + broadcast questionResults" instead of two.
  """
  @spec show_results(String.t(), String.t()) :: :ok | {:error, :not_found | :not_authorized}
  def show_results(game_id, host_id) do
    GenServer.call(__MODULE__, {:show_results, game_id, host_id})
  end

  @doc "The fixed list of avatar emoji players can choose from."
  @spec get_available_avatars() :: [String.t()]
  def get_available_avatars do
    Player.available_avatars()
  end

  @doc "Aggregate stats across all non-finished games — how many are active, and how many players are in them."
  @spec get_stats() :: %{active_games: non_neg_integer(), active_players: non_neg_integer()}
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # ------- Callbacks -------

  # TODO: state is 4 parallel maps all keyed by game_id (games, answers,
  # question_results_shown, question_timers), so most operations touch up to
  # 3 of them in lockstep. Consolidating into one nested per-game struct would
  # be cleaner, but it's the riskiest change identified in this codebase's
  # refactor — it touches nearly every clause below, no concrete bug is
  # attributed to the current shape (just architectural inelegance), and the
  # test suite here is happy-path coverage, not exhaustive concurrent/
  # multi-game coverage. Deliberately deferred to a future effort that starts
  # with a much more thorough Game.Server test suite first.
  @impl true
  def init(_) do
    {:ok, %{games: %{}, answers: %{}, question_results_shown: %{}, question_timers: %{}}}
  end

  @impl true
  def handle_call({:create_game, host_id, host_name, avatar}, _from, state) do
    game_id = IdGenerator.generate_game_id()
    host = Player.new(host_id, host_name, true, avatar)
    questions = Question.get_random(5)

    game = %{
      id: game_id,
      host_id: host_id,
      players: [host],
      questions: questions,
      current_question_index: -1,
      status: :waiting,
      current_question_start_time: nil
    }

    new_state =
      state
      |> put_in([:games, game_id], game)
      |> put_in([:answers, game_id], [])
      |> put_in([:question_results_shown, game_id], MapSet.new())
      |> broadcast_stats_update()

    {:reply, {:ok, serialize_game(game)}, new_state}
  end

  def handle_call({:join_game, game_id, player_id, player_name, avatar}, _from, state) do
    case get_in(state, [:games, game_id]) do
      nil ->
        {:reply, {:error, :game_not_found}, state}

      %{status: status} when status != :waiting ->
        {:reply, {:error, :already_started}, state}

      game ->
        player = Player.new(player_id, player_name, false, avatar)
        updated_game = %{game | players: game.players ++ [player]}

        new_state =
          state
          |> put_in([:games, game_id], updated_game)
          |> broadcast_stats_update()

        {:reply, {:ok, serialize_game(updated_game), serialize_player(player)}, new_state}
    end
  end

  def handle_call({:start_game, game_id, host_id}, _from, state) do
    case get_in(state, [:games, game_id]) do
      %{host_id: ^host_id, status: :waiting} = game ->
        now = DateTime.utc_now() |> DateTime.to_iso8601()

        updated_game = %{
          game
          | status: :playing,
            current_question_index: 0,
            current_question_start_time: now
        }

        new_state =
          state
          |> put_in([:games, game_id], updated_game)
          |> put_in([:question_results_shown, game_id], MapSet.new())
          |> schedule_question_timer(game_id, updated_game)

        {:reply, {:ok, serialize_game(updated_game)}, new_state}

      _ ->
        {:reply, {:error, :cannot_start}, state}
    end
  end

  def handle_call({:next_question, game_id, host_id}, _from, state) do
    case get_in(state, [:games, game_id]) do
      %{host_id: ^host_id, status: :playing} = game ->
        next_index = game.current_question_index + 1

        state = cancel_question_timer(state, game_id)

        updated_game =
          if next_index >= length(game.questions) do
            %{game | status: :finished, current_question_index: next_index}
          else
            now = DateTime.utc_now() |> DateTime.to_iso8601()
            %{game | current_question_index: next_index, current_question_start_time: now}
          end

        new_state =
          state
          |> put_in([:games, game_id], updated_game)
          |> schedule_question_timer(game_id, updated_game)
          |> maybe_broadcast_stats_on_finish(updated_game)

        {:reply, {:ok, serialize_game(updated_game)}, new_state}

      _ ->
        {:reply, {:error, :cannot_advance}, state}
    end
  end

  def handle_call({:submit_answer, game_id, player_id, question_id, answer}, _from, state) do
    with {:ok, game} <- fetch_playing_game(state, game_id),
         {:ok, current_question} <- fetch_matching_question(game, question_id),
         :ok <- ensure_not_already_answered(state, game_id, player_id, question_id) do
      updated_game = apply_answer_score(game, current_question, player_id, answer)

      new_state =
        state
        |> put_in([:games, game_id], updated_game)
        |> record_answer(game_id, player_id, question_id, answer)
        |> maybe_broadcast_question_results_if_complete(game_id, question_id)

      {:reply, {:ok, serialize_game(updated_game)}, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
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
    question = game && current_question_for(game)

    {:reply, question && Question.serialize(question), state}
  end

  def handle_call({:show_results, game_id, host_id}, _from, state) do
    case get_in(state, [:games, game_id]) do
      %{host_id: ^host_id} = game ->
        new_state =
          case current_question_for(game) do
            nil -> state
            question -> maybe_broadcast_question_results(state, game_id, question.id)
          end

        {:reply, :ok, new_state}

      nil ->
        {:reply, {:error, :not_found}, state}

      _ ->
        {:reply, {:error, :not_authorized}, state}
    end
  end

  def handle_call({:get_leaderboard, game_id}, _from, state) do
    game = get_in(state, [:games, game_id])

    result = if game, do: sorted_leaderboard(game), else: []

    {:reply, result, state}
  end

  def handle_call({:get_answer_stats, game_id, question_id}, _from, state) do
    {:reply, get_answer_stats_from_state(state, game_id, question_id), state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, compute_stats(state), state}
  end

  def handle_call({:leave_game, game_id, player_id}, _from, state) do
    case get_in(state, [:games, game_id]) do
      nil ->
        {:reply, :ok, state}

      game ->
        remaining_players = Enum.reject(game.players, &(&1.id == player_id))

        updated_game =
          if remaining_players == [] do
            %{game | players: remaining_players, status: :finished}
          else
            %{game | players: remaining_players}
          end

        if remaining_players != [] do
          Endpoint.broadcast!("game:#{game_id}", "playerLeft", %{
            playerId: player_id,
            game: serialize_game(updated_game)
          })
        end

        new_state =
          state
          |> put_in([:games, game_id], updated_game)
          |> broadcast_stats_update()

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_info({:auto_show_results, game_id, question_id}, state) do
    new_state = maybe_broadcast_question_results(state, game_id, question_id)
    {:noreply, new_state}
  end

  # ------- Private helpers -------

  defp current_question_for(game) do
    if game.current_question_index >= 0 and game.current_question_index < length(game.questions) do
      Enum.at(game.questions, game.current_question_index)
    else
      nil
    end
  end

  defp fetch_playing_game(state, game_id) do
    case get_in(state, [:games, game_id]) do
      %{status: :playing} = game -> {:ok, game}
      _ -> {:error, :invalid_game}
    end
  end

  defp fetch_matching_question(game, question_id) do
    case current_question_for(game) do
      %{id: ^question_id} = question -> {:ok, question}
      _ -> {:error, :invalid_question}
    end
  end

  defp ensure_not_already_answered(state, game_id, player_id, question_id) do
    game_answers = get_in(state, [:answers, game_id]) || []

    already_answered? =
      Enum.any?(game_answers, fn a ->
        a.player_id == player_id and a.question_id == question_id
      end)

    if already_answered?, do: {:error, :already_answered}, else: :ok
  end

  defp apply_answer_score(game, current_question, player_id, answer) do
    if answer == current_question.correct_answer do
      points = calculate_points(game.current_question_start_time, current_question.time_limit)

      updated_players =
        Enum.map(game.players, fn p ->
          if p.id == player_id, do: %{p | score: p.score + points}, else: p
        end)

      %{game | players: updated_players}
    else
      game
    end
  end

  defp calculate_points(question_start_time, time_limit) do
    time_taken = calc_time_taken(question_start_time)
    time_bonus = max(0, time_limit - time_taken)
    round(@base_points + time_bonus * @time_bonus_multiplier)
  end

  defp record_answer(state, game_id, player_id, question_id, answer) do
    answer_record = %{
      player_id: player_id,
      question_id: question_id,
      answer: answer,
      answered_at: DateTime.utc_now()
    }

    update_in(state, [:answers, game_id], fn answers -> (answers || []) ++ [answer_record] end)
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

  defp schedule_question_timer(state, game_id, game) do
    state = cancel_question_timer(state, game_id)

    question = Enum.at(game.questions, game.current_question_index)

    cond do
      game.status != :playing or is_nil(question) ->
        state

      true ->
        timer_ms = max(0, question.time_limit * 1000)
        ref = Process.send_after(self(), {:auto_show_results, game_id, question.id}, timer_ms)
        put_in(state, [:question_timers, game_id], %{ref: ref, question_id: question.id})
    end
  end

  defp cancel_question_timer(state, game_id) do
    case get_in(state, [:question_timers, game_id]) do
      %{ref: ref} ->
        Process.cancel_timer(ref)
        update_in(state, [:question_timers], fn timers -> Map.delete(timers || %{}, game_id) end)

      _ ->
        state
    end
  end

  defp maybe_broadcast_question_results_if_complete(state, game_id, question_id) do
    stats = get_answer_stats_from_state(state, game_id, question_id)

    if stats.pending <= 0 do
      maybe_broadcast_question_results(state, game_id, question_id)
    else
      state
    end
  end

  defp maybe_broadcast_question_results(state, game_id, question_id) do
    game = get_in(state, [:games, game_id])
    question = game && current_question_for(game)

    cond do
      is_nil(game) or game.status != :playing ->
        state

      is_nil(question) or question.id != question_id ->
        state

      question_results_already_shown?(state, game_id, question_id) ->
        state

      true ->
        leaderboard = sorted_leaderboard(game)

        Endpoint.broadcast!(
          "game:#{game_id}",
          "questionResults",
          %{question: Question.serialize(question), leaderboard: leaderboard}
        )

        state
        |> mark_question_result_as_shown(game_id, question_id)
        |> cancel_question_timer(game_id)
    end
  end

  defp sorted_leaderboard(game) do
    game.players
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.map(&serialize_player/1)
  end

  defp compute_stats(state) do
    active_games =
      state.games
      |> Map.values()
      |> Enum.filter(&(&1.status != :finished))

    %{
      active_games: length(active_games),
      active_players: active_games |> Enum.flat_map(& &1.players) |> length()
    }
  end

  # Lets the home screen's connection widget update live — pushed to every
  # client on the shared lobby topic whenever active_games/active_players
  # could have changed (a game is created/joined/left, or finishes).
  defp broadcast_stats_update(state) do
    stats = compute_stats(state)

    Endpoint.broadcast!("game:lobby", "statsUpdated", %{
      activeGames: stats.active_games,
      activePlayers: stats.active_players
    })

    state
  end

  defp maybe_broadcast_stats_on_finish(state, %{status: :finished}), do: broadcast_stats_update(state)
  defp maybe_broadcast_stats_on_finish(state, _game), do: state

  defp question_results_already_shown?(state, game_id, question_id) do
    shown_set = get_in(state, [:question_results_shown, game_id]) || MapSet.new()
    MapSet.member?(shown_set, question_id)
  end

  defp mark_question_result_as_shown(state, game_id, question_id) do
    update_in(state, [:question_results_shown], fn shown_map ->
      shown_map = shown_map || %{}
      shown_set = Map.get(shown_map, game_id, MapSet.new())
      Map.put(shown_map, game_id, MapSet.put(shown_set, question_id))
    end)
  end

  defp get_answer_stats_from_state(state, game_id, question_id) do
    game = get_in(state, [:games, game_id])
    game_answers = get_in(state, [:answers, game_id]) || []

    if game do
      answered_count = Enum.count(game_answers, fn a -> a.question_id == question_id end)
      total = length(game.players)

      %{total: total, answered: answered_count, pending: total - answered_count}
    else
      %{total: 0, answered: 0, pending: 0}
    end
  end

  # Serialize game to camelCase JSON-friendly map (matches frontend expectations)
  defp serialize_game(game) do
    %{
      id: game.id,
      hostId: game.host_id,
      players: Enum.map(game.players, &serialize_player/1),
      questions: Enum.map(game.questions, &Question.serialize/1),
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

end
