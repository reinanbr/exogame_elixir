export const DEFAULT_AVATAR = '🚀';

export const MEDAL_EMOJIS = ['🥇', '🥈', '🥉'] as const;

/** Base HTTP URL for the Phoenix backend's REST endpoints (distinct from the WebSocket URL). */
export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001';
