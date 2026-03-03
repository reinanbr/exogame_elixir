'use client';

import React, { createContext, useContext, useEffect, useState, useCallback, useRef } from 'react';
import { Socket as PhoenixSocket } from 'phoenix';
import { Game, Player, Question, GameContextType, AnswerStats } from '@/types/game.types';

const GameContext = createContext<GameContextType | undefined>(undefined);

export function GameProvider({ children }: { children: React.ReactNode }) {
  const channelRef = useRef<ReturnType<PhoenixSocket['channel']> | null>(null);
  const socketRef = useRef<PhoenixSocket | null>(null);
  const [game, setGame] = useState<Game | null>(null);
  const [player, setPlayer] = useState<Player | null>(null);
  const [currentQuestion, setCurrentQuestion] = useState<Question | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [leaderboard, setLeaderboard] = useState<Player[]>([]);
  const [showingResults, setShowingResults] = useState(false);
  const [answerStats, setAnswerStats] = useState<AnswerStats | null>(null);
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [_, setPlayerId] = useState<string | null>(null);

  // Join a game-specific channel to receive broadcasts
  const joinGameChannel = useCallback((gameId: string) => {
    if (!socketRef.current) return;

    const gameChannel = socketRef.current.channel(`game:${gameId}`, {});
    
    gameChannel.on('playerJoined', (data: { player: Player; game: Game }) => {
      setGame(data.game);
    });

    gameChannel.on('gameStarted', (data: { game: Game; currentQuestion: Question }) => {
      setGame(data.game);
      setCurrentQuestion(data.currentQuestion);
      setLeaderboard([]);
      setShowingResults(false);
      setAnswerStats(null);
    });

    gameChannel.on('nextQuestion', (data: { game: Game; currentQuestion: Question }) => {
      console.log('Nova pergunta recebida:', data);
      setGame(data.game);
      setCurrentQuestion(data.currentQuestion);
      setLeaderboard([]);
      setShowingResults(false);
      setAnswerStats(null);
    });

    gameChannel.on('answerStatsUpdated', (data: { stats: AnswerStats; questionId: string }) => {
      console.log('Estatísticas de respostas atualizadas:', data);
      setAnswerStats(data.stats);
    });

    gameChannel.on('questionResults', (data: { question: Question; leaderboard: Player[] }) => {
      console.log('Resultados recebidos:', data);
      setCurrentQuestion(data.question);
      setLeaderboard(data.leaderboard);
      setShowingResults(true);
    });

    gameChannel.on('gameFinished', (data: { game: Game; leaderboard: Player[] }) => {
      setGame(data.game);
      setLeaderboard(data.leaderboard);
      setCurrentQuestion(null);
    });

    gameChannel.join()
      .receive('ok', () => {
        console.log(`Joined game channel: game:${gameId}`);
      })
      .receive('error', (resp: unknown) => {
        console.error(`Failed to join game channel: game:${gameId}`, resp);
      });

    return gameChannel;
  }, []);

  useEffect(() => {
    const phoenixSocket = new PhoenixSocket('ws://localhost:3001/socket', {});
    socketRef.current = phoenixSocket;

    phoenixSocket.onOpen(() => {
      setIsConnected(true);
      console.log('Conectado ao servidor Phoenix');
    });

    phoenixSocket.onClose(() => {
      setIsConnected(false);
      console.log('Desconectado do servidor Phoenix');
    });

    phoenixSocket.onError(() => {
      setIsConnected(false);
      console.error('Erro na conexão com servidor Phoenix');
    });

    phoenixSocket.connect();

    // Join the lobby channel for creating/joining games
    const lobbyChannel = phoenixSocket.channel('game:lobby', {});

    lobbyChannel.on('gameCreated', (data: { game: Game; playerId: string }) => {
      setGame(data.game);
      setPlayerId(data.playerId);
      const hostPlayer = data.game.players.find((p: Player) => p.id === data.playerId);
      if (hostPlayer) {
        setPlayer(hostPlayer);
      }
      // Join the game-specific channel for broadcasts
      joinGameChannel(data.game.id);
    });

    lobbyChannel.on('gameJoined', (data: { game: Game; player: Player }) => {
      setGame(data.game);
      setPlayer(data.player);
      setPlayerId(data.player.id);
      // Join the game-specific channel for broadcasts
      joinGameChannel(data.game.id);
    });

    lobbyChannel.on('answerSubmitted', () => {
      console.log('Resposta enviada com sucesso');
    });

    lobbyChannel.on('error', (data: { message: string; type?: string }) => {
      console.error('Erro:', data.message);
      if (data.type === 'ROOM_NOT_FOUND') {
        alert('⚠️ Sala não encontrada!\n\nO código da sala informado não existe ou a partida já foi iniciada. Verifique o código e tente novamente.');
      } else {
        alert(data.message);
      }
    });

    lobbyChannel.join()
      .receive('ok', (resp: { playerId?: string }) => {
        console.log('Conectado ao lobby', resp);
        if (resp.playerId) {
          setPlayerId(resp.playerId);
        }
      })
      .receive('error', (resp: unknown) => {
        console.error('Falha ao conectar ao lobby', resp);
      });

    channelRef.current = lobbyChannel;

    return () => {
      lobbyChannel.leave();
      phoenixSocket.disconnect();
    };
  }, [joinGameChannel]);

  const createGame = useCallback((hostName: string, avatar?: string) => {
    if (channelRef.current) {
      channelRef.current.push('createGame', { hostName, avatar });
    }
  }, []);

  const joinGame = useCallback((gameId: string, playerName: string, avatar?: string) => {
    if (channelRef.current) {
      channelRef.current.push('joinGame', { gameId, playerName, avatar });
    }
  }, []);

  const startGame = useCallback(() => {
    if (channelRef.current && game) {
      channelRef.current.push('startGame', { gameId: game.id });
    }
  }, [game]);

  const nextQuestion = useCallback(() => {
    if (channelRef.current && game) {
      channelRef.current.push('nextQuestion', { gameId: game.id });
    }
  }, [game]);

  const submitAnswer = useCallback((questionId: string, answer: number) => {
    if (channelRef.current) {
      channelRef.current.push('submitAnswer', { questionId, answer });
    }
  }, []);

  const showResults = useCallback(() => {
    if (channelRef.current && game) {
      channelRef.current.push('showResults', { gameId: game.id });
    }
  }, [game]);

  const isHost = player?.isHost || false;

  const value: GameContextType = {
    game,
    player,
    currentQuestion,
    isConnected,
    isHost,
    leaderboard,
    showingResults,
    answerStats,
    createGame,
    joinGame,
    startGame,
    nextQuestion,
    submitAnswer,
    showResults,
  };

  return <GameContext.Provider value={value}>{children}</GameContext.Provider>;
}

export function useGame() {
  const context = useContext(GameContext);
  if (context === undefined) {
    throw new Error('useGame must be used within a GameProvider');
  }
  return context;
}
