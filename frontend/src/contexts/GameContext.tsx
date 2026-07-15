'use client';

import React, { createContext, useContext, useEffect, useState, useCallback, useRef } from 'react';
import { Socket as PhoenixSocket } from 'phoenix';
import {
  Game,
  Player,
  Question,
  GameContextType,
  AnswerStats,
  Stats,
  GameCreatedPayload,
  GameJoinedPayload,
  PlayerJoinedPayload,
  PlayerLeftPayload,
  GameQuestionPayload,
  AnswerStatsUpdatedPayload,
  QuestionResultsPayload,
  GameFinishedPayload,
  StatsUpdatedPayload,
  ErrorPayload,
} from '@/types/game.types';

const PING_INTERVAL_MS = 5000;

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
  const [stats, setStats] = useState<Stats | null>(null);
  const [pingMs, setPingMs] = useState<number | null>(null);

  // Join a game-specific channel to receive broadcasts
  const joinGameChannel = useCallback((gameId: string) => {
    if (!socketRef.current) return;

    const gameChannel = socketRef.current.channel(`game:${gameId}`, {});
    
    gameChannel.on('playerJoined', (data: PlayerJoinedPayload) => {
      setGame(data.game);
    });

    gameChannel.on('playerLeft', (data: PlayerLeftPayload) => {
      setGame(data.game);
    });

    gameChannel.on('gameStarted', (data: GameQuestionPayload) => {
      setGame(data.game);
      setCurrentQuestion(data.currentQuestion);
      setLeaderboard([]);
      setShowingResults(false);
      setAnswerStats(null);
    });

    gameChannel.on('nextQuestion', (data: GameQuestionPayload) => {
      console.log('Nova pergunta recebida:', data);
      setGame(data.game);
      setCurrentQuestion(data.currentQuestion);
      setLeaderboard([]);
      setShowingResults(false);
      setAnswerStats(null);
    });

    gameChannel.on('answerStatsUpdated', (data: AnswerStatsUpdatedPayload) => {
      console.log('Estatísticas de respostas atualizadas:', data);
      setAnswerStats(data.stats);
    });

    gameChannel.on('questionResults', (data: QuestionResultsPayload) => {
      console.log('Resultados recebidos:', data);
      setCurrentQuestion(data.question);
      setLeaderboard(data.leaderboard);
      setShowingResults(true);
    });

    gameChannel.on('gameFinished', (data: GameFinishedPayload) => {
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
    const socketUrl = process.env.NEXT_PUBLIC_PHOENIX_URL ?? 'ws://localhost:3001/socket';
    const phoenixSocket = new PhoenixSocket(socketUrl, {});
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

    lobbyChannel.on('gameCreated', (data: GameCreatedPayload) => {
      setGame(data.game);
      const hostPlayer = data.game.players.find((p: Player) => p.id === data.playerId);
      if (hostPlayer) {
        setPlayer(hostPlayer);
      }
      // Join the game-specific channel for broadcasts
      joinGameChannel(data.game.id);
    });

    lobbyChannel.on('gameJoined', (data: GameJoinedPayload) => {
      setGame(data.game);
      setPlayer(data.player);
      // Join the game-specific channel for broadcasts
      joinGameChannel(data.game.id);
    });

    lobbyChannel.on('answerSubmitted', () => {
      console.log('Resposta enviada com sucesso');
    });

    lobbyChannel.on('statsUpdated', (data: StatsUpdatedPayload) => {
      setStats(data);
    });

    lobbyChannel.on('error', (data: ErrorPayload) => {
      console.error('Erro:', data.message);
      if (data.type === 'ROOM_NOT_FOUND') {
        alert('⚠️ Sala não encontrada!\n\nO código da sala informado não existe. Verifique o código e tente novamente.');
      } else if (data.type === 'ALREADY_STARTED') {
        alert('⚠️ Partida já iniciada!\n\nEssa sala já começou a partida e não aceita novos jogadores.');
      } else {
        alert(data.message);
      }
    });

    lobbyChannel.join()
      .receive('ok', (resp: { playerId?: string }) => {
        console.log('Conectado ao lobby', resp);
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

  // Round-trip latency to the backend, shown by the home screen's connection
  // widget — measured via a dedicated no-op "ping" channel event rather than
  // Phoenix's own heartbeat, since the heartbeat's timing isn't exposed here.
  useEffect(() => {
    if (!isConnected) {
      setPingMs(null);
      return;
    }

    const measurePing = () => {
      if (!channelRef.current) return;
      const start = performance.now();
      channelRef.current
        .push('ping', {})
        .receive('ok', () => setPingMs(Math.round(performance.now() - start)));
    };

    measurePing();
    const interval = setInterval(measurePing, PING_INTERVAL_MS);

    return () => clearInterval(interval);
  }, [isConnected]);

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
    stats,
    pingMs,
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
