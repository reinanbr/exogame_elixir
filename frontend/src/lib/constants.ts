export const DEFAULT_AVATAR = '🚀';

export const MEDAL_EMOJIS = ['🥇', '🥈', '🥉'] as const;

/** Base HTTP URL for the Phoenix backend's REST endpoints (distinct from the WebSocket URL). */
export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001';

/** Ping (ms) → indicator color, from best (green) to worst (red) latency. */
export const PING_COLOR_SCALE = [
{ min: 0,   max: 100,   color: "#00D294" },
    { min: 101,  max: 150,  color: "#64DD17" },
    { min: 151, max: 200,  color: "#AEEA00" },
    { min: 201, max: 250,  color: "#FFD600" },
    { min: 251, max: 300,  color: "#FFAB00" },
    { min: 301, max: 360,  color: "#f64e00" },
    { min: 361, max: 400,  color: "#ff3700" },
    { min: 401, max: 9999, color: "#D50000" }
] as const;

/** Looks up the indicator color for a given ping in ms, falling back to the best tier when `null`. */
export function getPingColor(pingMs: number | null): string {
  if (pingMs === null) return PING_COLOR_SCALE[0].color;
  const tier = PING_COLOR_SCALE.find((t) => pingMs >= t.min && pingMs <= t.max);
  return tier ? tier.color : PING_COLOR_SCALE[PING_COLOR_SCALE.length - 1].color;
}
