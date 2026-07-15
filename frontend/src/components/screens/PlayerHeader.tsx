'use client';

import { useGame } from '@/contexts/GameContext';
import { DEFAULT_AVATAR } from '@/lib/constants';

export default function PlayerHeader() {
  const { player, game } = useGame();

  if (!player || !game) {
    return null;
  }

  return (
    <div className="fixed top-0 left-0 right-0 z-50 glass-panel border-x-0 border-t-0 rounded-none">
      <div className="max-w-4xl mx-auto px-4 py-3 flex justify-between items-center">
        <div className="flex items-center">
          <div className="text-2xl mr-3">{player.avatar || DEFAULT_AVATAR}</div>
          <div className={`w-2.5 h-2.5 rounded-full mr-3 ${
            player.isHost ? 'bg-yellow-400 shadow-[0_0_8px_2px_rgba(250,204,21,0.6)]' : 'bg-emerald-400 shadow-[0_0_8px_2px_rgba(52,211,153,0.6)]'
          }`}></div>
          <span className="font-semibold text-white text-lg">{player.name}</span>
          <span className="ml-3 bg-gradient-to-r from-emerald-400 to-teal-500 text-white px-3 py-1 rounded-full text-sm font-bold shadow-lg shadow-emerald-500/20">
            {player.score.toLocaleString()} pts
          </span>
          {player.isHost && (
            <span className="ml-2 text-xs bg-yellow-400/20 text-yellow-300 border border-yellow-400/30 px-2 py-1 rounded-full">
              HOST
            </span>
          )}
        </div>

        <div className="text-center">
          <p className="text-xs text-white/50">Código da Sala</p>
          <p className="font-bold font-mono text-lg bg-gradient-to-r from-cyan-300 to-purple-300 bg-clip-text text-transparent tracking-wider">{game.id}</p>
        </div>
      </div>
    </div>
  );
}
