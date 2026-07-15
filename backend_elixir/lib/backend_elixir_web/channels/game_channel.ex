defmodule BackendElixirWeb.GameChannel do
  use BackendElixirWeb, :channel

  alias BackendElixir.Game.Server, as: GameServer
  alias BackendElixir.Game.Question
  alias BackendElixirWeb.Endpoint

  require Logger

  # Join the lobby topic — used for creating / joining games
  @impl true
  def join("game:lobby", _payload, socket) do
    Logger.info("Player #{socket.assigns.player_id} joined lobby")
    send(self(), :send_initial_stats)
    {:ok, %{playerId: socket.assigns.player_id}, socket}
  end

  # Join a specific game room
  def join("game:" <> game_id, _payload, socket) do
    Logger.info("Player #{socket.assigns.player_id} joined game room #{game_id}")
    socket = assign(socket, :game_id, game_id)
    {:ok, %{playerId: socket.assigns.player_id}, socket}
  end

  # ---- Event Handlers ----

  @impl true
  def handle_in("createGame", %{"hostName" => host_name} = payload, socket) do
    player_id = socket.assigns.player_id
    avatar = Map.get(payload, "avatar")

    case GameServer.create_game(player_id, host_name, avatar) do
      {:ok, game} ->
        socket = assign(socket, :game_id, game.id)

        push(socket, "gameCreated", %{game: game, playerId: player_id})

        {:reply, {:ok, %{success: true, gameId: game.id}}, socket}

      {:error, reason} ->
        push(socket, "error", %{message: "Erro ao criar jogo: #{reason}"})
        {:reply, {:error, %{success: false}}, socket}
    end
  end

  def handle_in("joinGame", %{"gameId" => game_id, "playerName" => player_name} = payload, socket) do
    player_id = socket.assigns.player_id
    avatar = Map.get(payload, "avatar")

    case GameServer.join_game(game_id, player_id, player_name, avatar) do
      {:ok, game, player} ->
        socket = assign(socket, :game_id, game_id)

        push(socket, "gameJoined", %{game: game, player: player})

        # Notify other players in the game room
        Endpoint.broadcast!(
          "game:#{game_id}",
          "playerJoined",
          %{player: player, game: game}
        )

        {:reply, {:ok, %{success: true}}, socket}

      {:error, :game_not_found} ->
        push(socket, "error", %{
          message: "A sala não existe. Verifique o código e tente novamente.",
          type: "ROOM_NOT_FOUND"
        })

        {:reply, {:error, %{success: false}}, socket}

      {:error, :already_started} ->
        push(socket, "error", %{
          message: "A sala já iniciou a partida. Não é possível entrar agora.",
          type: "ALREADY_STARTED"
        })

        {:reply, {:error, %{success: false}}, socket}
    end
  end

  def handle_in("startGame", %{"gameId" => game_id}, socket) do
    host_id = socket.assigns.player_id

    case GameServer.start_game(game_id, host_id) do
      {:ok, game} ->
        current_question = GameServer.get_current_question(game_id)

        # Strip correct answer before sending
        safe_question = Question.strip_answer(current_question)

        Endpoint.broadcast!(
          "game:#{game_id}",
          "gameStarted",
          %{game: game, currentQuestion: safe_question}
        )

        {:reply, {:ok, %{success: true}}, socket}

      {:error, _reason} ->
        push(socket, "error", %{message: "Não foi possível iniciar o jogo"})
        {:reply, {:error, %{success: false}}, socket}
    end
  end

  def handle_in("nextQuestion", %{"gameId" => game_id}, socket) do
    host_id = socket.assigns.player_id

    case GameServer.next_question(game_id, host_id) do
      {:ok, game} ->
        if game.status == :finished do
          leaderboard = GameServer.get_leaderboard(game_id)

          Endpoint.broadcast!(
            "game:#{game_id}",
            "gameFinished",
            %{game: game, leaderboard: leaderboard}
          )
        else
          current_question = GameServer.get_current_question(game_id)
          safe_question = Question.strip_answer(current_question)

          Endpoint.broadcast!(
            "game:#{game_id}",
            "nextQuestion",
            %{game: game, currentQuestion: safe_question}
          )
        end

        {:reply, {:ok, %{success: true}}, socket}

      {:error, _reason} ->
        push(socket, "error", %{message: "Não foi possível avançar para próxima pergunta"})
        {:reply, {:error, %{success: false}}, socket}
    end
  end

  def handle_in("submitAnswer", %{"questionId" => question_id, "answer" => answer}, socket) do
    player_id = socket.assigns.player_id
    game_id = socket.assigns[:game_id]

    if is_nil(game_id) do
      push(socket, "error", %{message: "Jogo não encontrado"})
      {:reply, {:error, %{success: false}}, socket}
    else
      case GameServer.submit_answer(game_id, player_id, question_id, answer) do
        {:ok, _game} ->
          # Send answer stats to all players
          stats = GameServer.get_answer_stats(game_id, question_id)

          Endpoint.broadcast!(
            "game:#{game_id}",
            "answerStatsUpdated",
            %{stats: stats, questionId: question_id}
          )

          push(socket, "answerSubmitted", %{success: true})
          {:reply, {:ok, %{success: true}}, socket}

        {:error, _reason} ->
          push(socket, "error", %{message: "Não foi possível enviar resposta"})
          {:reply, {:error, %{success: false}}, socket}
      end
    end
  end

  def handle_in("showResults", %{"gameId" => game_id}, socket) do
    host_id = socket.assigns.player_id

    case GameServer.show_results(game_id, host_id) do
      :ok ->
        {:reply, {:ok, %{success: true}}, socket}

      {:error, _reason} ->
        push(socket, "error", %{message: "Não autorizado"})
        {:reply, {:error, %{success: false}}, socket}
    end
  end

  def handle_in("getAvailableAvatars", _payload, socket) do
    avatars = GameServer.get_available_avatars()
    push(socket, "availableAvatars", %{avatars: avatars})
    {:reply, {:ok, %{success: true, avatars: avatars}}, socket}
  end

  # Round-trip latency probe for the home screen's connection widget — the
  # client times how long this reply takes to come back.
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{}}, socket}
  end

  # ---- Helpers ----

  # Handle PubSub broadcast messages received by the lobby channel
  # These are sent by Endpoint.subscribe/broadcast but are already handled
  # by the game-specific channels, so we just ignore them here.
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    {:noreply, socket}
  end

  # Sent to self/1 right after joining the lobby, so every newly connected
  # client gets an immediate stats snapshot instead of waiting for someone
  # else's action to trigger the next broadcast.
  def handle_info(:send_initial_stats, socket) do
    stats = GameServer.get_stats()
    push(socket, "statsUpdated", %{activeGames: stats.active_games, activePlayers: stats.active_players})
    {:noreply, socket}
  end

  # Fires when this channel process terminates for any reason — including
  # the socket disconnecting (tab closed, network dropped). If this channel
  # had joined a specific game room, treat that as the player leaving it, so
  # the "active astronauts" count stays accurate.
  @impl true
  def terminate(_reason, socket) do
    case socket.assigns[:game_id] do
      nil -> :ok
      game_id -> GameServer.leave_game(game_id, socket.assigns.player_id)
    end

    :ok
  end
end
