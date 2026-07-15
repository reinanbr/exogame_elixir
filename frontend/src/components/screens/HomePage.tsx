'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useGame } from '@/contexts/GameContext';
import { DEFAULT_AVATAR } from '@/lib/constants';
import AvatarSelector from '../shared/AvatarSelector';
import ConnectionStatus from '../shared/ConnectionStatus';
import ScreenLayout from '../shared/ScreenLayout';
import SplashScreen from '../space/SplashScreen';

const MIN_SPLASH_MS = 100;

export default function HomePage() {
  const [hostName, setHostName] = useState('');
  const [gameId, setGameId] = useState('');
  const [playerName, setPlayerName] = useState('');
  const [selectedAvatar, setSelectedAvatar] = useState(DEFAULT_AVATAR);
  const [mode, setMode] = useState<'menu' | 'create' | 'join'>('menu');
  const [minTimeElapsed, setMinTimeElapsed] = useState(false);
  const [splashDone, setSplashDone] = useState(false);

  const { createGame, joinGame, isConnected } = useGame();

  useEffect(() => {
    const timer = setTimeout(() => setMinTimeElapsed(true), MIN_SPLASH_MS);
    return () => clearTimeout(timer);
  }, []);

  // Once we're actually ready (connected, past the minimum splash time), the
  // splash animation accelerates to finish its current lap on its own —
  // splashDone flips only when it naturally completes, never mid-frame.
  const readyToFinish = isConnected && minTimeElapsed;

  const handleCreateGame = (e: React.FormEvent) => {
    e.preventDefault();
    if (hostName.trim()) {
      createGame(hostName.trim(), selectedAvatar);
    }
  };

  const handleJoinGame = (e: React.FormEvent) => {
    e.preventDefault();
    if (gameId.trim() && playerName.trim()) {
      joinGame(gameId.trim().toUpperCase(), playerName.trim(), selectedAvatar);
    }
  };

  if (!splashDone) {
    return (
      <SplashScreen
        finish={readyToFinish}
        onFinish={() => setSplashDone(true)}
        message={isConnected ? 'Sincronizando com a estação...' : 'Estabelecendo contato com a base...'}
      />
    );
  }

  return (
    <>
    <ScreenLayout maxWidth="max-w-md">
        <div className="text-center mb-8">
          <div className="text-5xl mb-3">🪐</div>
          <h1 className="font-heading text-4xl font-extrabold mb-2 bg-gradient-to-r from-cyan-300 via-purple-300 to-pink-300 bg-clip-text text-transparent tracking-wide">
            ExoGame
          </h1>
          <p className="text-white/60">Quiz em tempo real entre exoplanetas</p>
        </div>

        {mode === 'menu' && (
          <div className="space-y-4">
            <button
              onClick={() => setMode('create')}
              className="w-full bg-gradient-to-r from-emerald-400 to-teal-500 hover:from-emerald-300 hover:to-teal-400 text-white font-bold py-3 px-4 rounded-xl transition duration-200 shadow-lg shadow-emerald-500/25 hover:shadow-emerald-400/40 hover:scale-[1.02]"
            >
              🚀 Criar Jogo
            </button>
            <button
              onClick={() => setMode('join')}
              className="w-full bg-gradient-to-r from-cyan-400 to-blue-500 hover:from-cyan-300 hover:to-blue-400 text-white font-bold py-3 px-4 rounded-xl transition duration-200 shadow-lg shadow-blue-500/25 hover:shadow-blue-400/40 hover:scale-[1.02]"
            >
              🛸 Entrar em Jogo
            </button>
          </div>
        )}

        {mode === 'create' && (
          <form onSubmit={handleCreateGame} className="space-y-4">
            <div>
              <label htmlFor="hostName" className="block text-sm font-medium text-white/70 mb-1">
                Seu Nome
              </label>
              <input
                type="text"
                id="hostName"
                value={hostName}
                onChange={(e) => setHostName(e.target.value)}
                className="w-full px-3 py-2 bg-white/5 border border-white/15 rounded-md text-white placeholder-white/30 focus:outline-none focus:ring-2 focus:ring-emerald-400/70"
                placeholder="Digite seu nome"
                required
              />
            </div>

            <AvatarSelector
              selectedAvatar={selectedAvatar}
              onAvatarSelect={setSelectedAvatar}
            />

            <div className="flex space-x-2">
              <button
                type="button"
                onClick={() => setMode('menu')}
                className="flex-1 bg-white/10 hover:bg-white/20 border border-white/15 text-white/80 font-bold py-2 px-4 rounded-lg transition duration-200"
              >
                Voltar
              </button>
              <button
                type="submit"
                className="flex-1 bg-gradient-to-r from-emerald-400 to-teal-500 hover:from-emerald-300 hover:to-teal-400 text-white font-bold py-2 px-4 rounded-lg transition duration-200 shadow-lg shadow-emerald-500/25"
              >
                Criar
              </button>
            </div>
          </form>
        )}

        {mode === 'join' && (
          <form onSubmit={handleJoinGame} className="space-y-4">
            <div>
              <label htmlFor="gameId" className="block text-sm font-medium text-white/70 mb-1">
                Código do Jogo
              </label>
              <input
                type="text"
                id="gameId"
                value={gameId}
                onChange={(e) => setGameId(e.target.value.toUpperCase())}
                className="w-full px-3 py-2 bg-white/5 border border-white/15 rounded-md text-white placeholder-white/30 focus:outline-none focus:ring-2 focus:ring-cyan-400/70 uppercase tracking-widest font-mono"
                placeholder="CÓDIGO"
                maxLength={6}
                required
              />
            </div>
            <div>
              <label htmlFor="playerName" className="block text-sm font-medium text-white/70 mb-1">
                Seu Nome
              </label>
              <input
                type="text"
                id="playerName"
                value={playerName}
                onChange={(e) => setPlayerName(e.target.value)}
                className="w-full px-3 py-2 bg-white/5 border border-white/15 rounded-md text-white placeholder-white/30 focus:outline-none focus:ring-2 focus:ring-cyan-400/70"
                placeholder="Digite seu nome"
                required
              />
            </div>

            <AvatarSelector
              selectedAvatar={selectedAvatar}
              onAvatarSelect={setSelectedAvatar}
            />

            <div className="flex space-x-2">
              <button
                type="button"
                onClick={() => setMode('menu')}
                className="flex-1 bg-white/10 hover:bg-white/20 border border-white/15 text-white/80 font-bold py-2 px-4 rounded-lg transition duration-200"
              >
                Voltar
              </button>
              <button
                type="submit"
                className="flex-1 bg-gradient-to-r from-cyan-400 to-blue-500 hover:from-cyan-300 hover:to-blue-400 text-white font-bold py-2 px-4 rounded-lg transition duration-200 shadow-lg shadow-blue-500/25"
              >
                Entrar
              </button>
            </div>
          </form>
        )}

        <div className="text-center mt-6">
          <Link href="/about" className="text-white/40 hover:text-white/70 text-sm transition-colors">
            Sobre o projeto
          </Link>
        </div>
    </ScreenLayout>
    <ConnectionStatus />
    </>
  );
}
