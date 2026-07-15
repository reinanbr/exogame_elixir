'use client';

import { useGame } from '@/contexts/GameContext';
import { DEFAULT_AVATAR } from '@/lib/constants';
import PlayerHeader from './PlayerHeader';
import ScreenLayout from '../shared/ScreenLayout';

export default function Lobby() {
  const { game, player, isHost, startGame } = useGame();

  if (!game || !player) {
    return null;
  }

  return (
    <div>
      <PlayerHeader />
      <ScreenLayout maxWidth="max-w-2xl" showHeaderOffset>
          <div className="text-center mb-8">
            <div className="text-5xl mb-2">🛰️</div>
            <h1 className="font-heading text-3xl font-bold mb-2 text-white">Sala de Espera</h1>
            <div className="glass-row rounded-lg p-4 mb-4">
              <p className="text-sm text-white/50 mb-1">Código do Jogo</p>
              <p className="text-3xl font-bold bg-gradient-to-r from-cyan-300 to-purple-300 bg-clip-text text-transparent font-mono tracking-wider">{game.id}</p>
            </div>
            <p className="text-white/60">Compartilhe o código com outros exploradores</p>
          </div>

          <div className="mb-8">
            <h2 className="text-xl font-semibold text-white mb-4">
              Tripulação ({game.players.length})
            </h2>
            <div className="space-y-2">
              {game.players.map((p) => (
                <div
                  key={p.id}
                  className={`flex items-center justify-between p-3 rounded-lg ${
                    p.isHost
                      ? 'bg-yellow-400/10 border-2 border-yellow-400/40'
                      : 'glass-row'
                  }`}
                >
                  <div className="flex items-center">
                    <div className="text-2xl mr-3">{p.avatar || DEFAULT_AVATAR}</div>
                    <div className={`w-3 h-3 rounded-full mr-3 ${
                      p.isHost ? 'bg-yellow-400 shadow-[0_0_8px_2px_rgba(250,204,21,0.6)]' : 'bg-emerald-400 shadow-[0_0_8px_2px_rgba(52,211,153,0.6)]'
                    }`}></div>
                    <span className="font-medium text-white">{p.name}</span>
                  </div>
                  {p.isHost && (
                    <span className="text-xs bg-yellow-400/20 text-yellow-300 border border-yellow-400/30 px-2 py-1 rounded-full">
                      HOST
                    </span>
                  )}
                </div>
              ))}
            </div>
          </div>

          {isHost && (
            <div className="text-center">
              <button
                onClick={startGame}
                disabled={game.players.length < 2}
                className={`px-8 py-3 rounded-xl font-bold text-white transition duration-200 ${
                  game.players.length >= 2
                    ? 'bg-gradient-to-r from-emerald-400 to-teal-500 hover:from-emerald-300 hover:to-teal-400 shadow-lg shadow-emerald-500/25 hover:scale-[1.02]'
                    : 'bg-white/10 text-white/40 cursor-not-allowed'
                }`}
              >
                {game.players.length >= 2 ? '🚀 Iniciar Jogo' : 'Aguardando mais tripulantes...'}
              </button>
              <p className="text-sm text-white/40 mt-2">
                Mínimo de 2 jogadores para iniciar
              </p>
            </div>
          )}

          {!isHost && (
            <div className="text-center">
              <div className="animate-pulse">
                <div className="inline-flex items-center text-white/60">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-cyan-400 mr-2"></div>
                  Aguardando o host iniciar a missão...
                </div>
              </div>
            </div>
          )}

          <div className="mt-8 p-4 glass-row rounded-lg">
            <h3 className="font-semibold text-cyan-300 mb-2">🔭 Como jogar:</h3>
            <ul className="text-sm text-white/70 space-y-1">
              <li>• Responda as perguntas o mais rápido possível</li>
              <li>• Pontos são dados por respostas corretas e velocidade</li>
              <li>• O explorador com mais pontos vence!</li>
            </ul>
          </div>
      </ScreenLayout>
    </div>
  );
}
