export interface Question {
  id: string;
  text: string;
  options: string[];
  correctAnswer?: number;
  correctAnswerContext?: string;
  timeLimit: number;
}

export interface Player {
  id: string;
  name: string;
  score: number;
  isHost: boolean;
  avatar: string;
}

export interface AnswerStats {
  total: number;
  answered: number;
  pending: number;
}

/** Global activity counts shown by the home screen's connection widget. */
export interface Stats {
  activeGames: number;
  activePlayers: number;
}

export interface Game {
  id: string;
  hostId: string;
  players: Player[];
  questions: Question[];
  currentQuestionIndex: number;
  status: 'waiting' | 'playing' | 'finished';
  /** ISO 8601 timestamp string as sent by the backend (`DateTime.to_iso8601/1`), not a Date instance. */
  currentQuestionStartTime?: string;
}

// Phoenix channel event payloads — shapes GameContext.tsx's channel.on(...)
// handlers receive from the backend (see game_channel.ex's broadcast!/push calls).
export interface GameCreatedPayload {
  game: Game;
  playerId: string;
}

export interface GameJoinedPayload {
  game: Game;
  player: Player;
}

export interface PlayerJoinedPayload {
  game: Game;
}

export interface PlayerLeftPayload {
  playerId: string;
  game: Game;
}

export type StatsUpdatedPayload = Stats;

export interface GameQuestionPayload {
  game: Game;
  currentQuestion: Question;
}

export interface AnswerStatsUpdatedPayload {
  stats: AnswerStats;
}

export interface QuestionResultsPayload {
  question: Question;
  leaderboard: Player[];
}

export interface GameFinishedPayload {
  game: Game;
  leaderboard: Player[];
}

export interface ErrorPayload {
  message: string;
  type?: 'ROOM_NOT_FOUND' | 'ALREADY_STARTED';
}

export interface GameContextType {
  game: Game | null;
  player: Player | null;
  currentQuestion: Question | null;
  isConnected: boolean;
  isHost: boolean;
  leaderboard: Player[];
  showingResults: boolean;
  answerStats: AnswerStats | null;
  stats: Stats | null;
  /** Round-trip latency to the backend in milliseconds, or `null` before the first measurement. */
  pingMs: number | null;

  // Actions
  createGame: (hostName: string, avatar?: string) => void;
  joinGame: (gameId: string, playerName: string, avatar?: string) => void;
  startGame: () => void;
  nextQuestion: () => void;
  submitAnswer: (questionId: string, answer: number) => void;
  showResults: () => void;
}
