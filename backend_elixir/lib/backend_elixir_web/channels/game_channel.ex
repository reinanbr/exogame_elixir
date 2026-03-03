defmodule BackendElixirWeb.GameChannel do
  use BackendElixirWeb, :channel

  alias BackendElixir.Game.Server, as: GameServer

  require Logger

  # Join the lobby topic — used for creating / joining games
  @impl true
  def join("game:lobby", _payload, socket) do
    Logger.info("Player #{socket.assigns.player_id} joined lobby")
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
        BackendElixirWeb.Endpoint.broadcast!(
          "game:#{game_id}",
          "playerJoined",
          %{player: player, game: game}
        )

        {:reply, {:ok, %{success: true}}, socket}

      {:error, _reason} ->
        push(socket, "error", %{
          message: "A sala não existe ou já foi iniciada",
          type: "ROOM_NOT_FOUND"
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
        safe_question = strip_correct_answer(current_question)

        BackendElixirWeb.Endpoint.broadcast!(
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
        if game.status == "finished" do
          leaderboard = GameServer.get_leaderboard(game_id)

          BackendElixirWeb.Endpoint.broadcast!(
            "game:#{game_id}",
            "gameFinished",
            %{game: game, leaderboard: leaderboard}
          )
        else
          current_question = GameServer.get_current_question(game_id)
          safe_question = strip_correct_answer(current_question)

          BackendElixirWeb.Endpoint.broadcast!(
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

          BackendElixirWeb.Endpoint.broadcast!(
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
    game = GameServer.get_game(game_id)

    if is_nil(game) or game.hostId != socket.assigns.player_id do
      push(socket, "error", %{message: "Não autorizado"})
      {:reply, {:error, %{success: false}}, socket}
    else
      current_question = GameServer.get_current_question(game_id)
      leaderboard = GameServer.get_leaderboard(game_id)

      BackendElixirWeb.Endpoint.broadcast!(
        "game:#{game_id}",
        "questionResults",
        %{question: current_question, leaderboard: leaderboard}
      )

      {:reply, {:ok, %{success: true}}, socket}
    end
  end

  def handle_in("getAvailableAvatars", _payload, socket) do
    avatars = GameServer.get_available_avatars()
    push(socket, "availableAvatars", %{avatars: avatars})
    {:reply, {:ok, %{success: true, avatars: avatars}}, socket}
  end

  # ---- Helpers ----

  # Handle PubSub broadcast messages received by the lobby channel
  # These are sent by Endpoint.subscribe/broadcast but are already handled
  # by the game-specific channels, so we just ignore them here.
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    {:noreply, socket}
  end

  defp strip_correct_answer(nil), do: nil

  defp strip_correct_answer(question) do
    Map.drop(question, [:correctAnswer])
  end
end
