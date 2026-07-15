'use client';

import { useGame } from '@/contexts/GameContext';

export default function ConnectionStatus() {
  const { isConnected, stats, pingMs } = useGame();

  return (
    <div className="fixed bottom-4 left-4 z-30 glass-panel rounded-2xl px-4 py-3 pointer-events-none select-none">
      {isConnected ? (
        <div className="flex items-center gap-3">
          <span className="text-3xl">📡</span>
          <div className="flex flex-col gap-1">
            <div className="flex items-center gap-1.5">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-400" />
              </span>
              <span className="text-xs font-semibold text-emerald-300">
                Conectado à base{pingMs !== null ? ` (${pingMs}ms)` : ''}
              </span>
            </div>
            <div className="text-[11px] text-white/60 whitespace-nowrap">
              🚀 {stats?.activeGames ?? '—'} naves ativas · 🧑‍🚀 {stats?.activePlayers ?? '—'}{' '}
              astronautas
            </div>
          </div>
        </div>
      ) : (
        <div className="flex items-center gap-3">
          <span className="text-3xl animate-float-slow">🧑‍🚀</span>
          <div className="flex items-center gap-1.5">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-rose-500 opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-rose-500" />
            </span>
            <span className="text-xs font-semibold text-rose-300">
              Conexão perdida com a base
            </span>
          </div>
        </div>
      )}
    </div>
  );
}
