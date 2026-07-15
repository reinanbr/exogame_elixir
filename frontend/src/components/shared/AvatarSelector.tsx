'use client';

import React, { useState } from 'react';
import { DEFAULT_AVATAR } from '@/lib/constants';

interface AvatarSelectorProps {
  selectedAvatar: string;
  onAvatarSelect: (avatar: string) => void;
  availableAvatars?: string[];
}

const defaultAvatars = [
  DEFAULT_AVATAR, '🛸', '👽', '🤖', '🪐', '🌍', '🌎', '🌏',
  '🌕', '🌙', '⭐', '🌟', '💫', '✨', '☄️', '🔭',
  '🛰️', '👨‍🚀', '👩‍🚀', '🌌', '🌠', '🌑', '🌒', '🌓',
  '🌔', '🌖', '🌗', '🌘', '⚡', '🌞', '🔥', '💥'
];

export default function AvatarSelector({ selectedAvatar, onAvatarSelect, availableAvatars = defaultAvatars }: AvatarSelectorProps) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="relative">
      <label className="block text-sm font-medium text-white/70 mb-2">
        Escolha seu avatar:
      </label>

      {/* Avatar selecionado */}
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className="w-16 h-16 text-3xl bg-white/5 border-2 border-white/15 rounded-full hover:border-cyan-400 focus:outline-none focus:border-cyan-400 transition-colors duration-200 flex items-center justify-center shadow-lg shadow-purple-900/30"
      >
        {selectedAvatar || DEFAULT_AVATAR}
      </button>

      {/* Lista de avatars */}
      {isOpen && (
        <div className="absolute top-20 left-0 z-20 bg-[#12082e]/95 backdrop-blur-xl border border-white/15 shadow-2xl shadow-black/50 rounded-lg p-4 grid grid-cols-8 gap-2 max-w-sm">
          {availableAvatars.map((avatar, index) => (
            <button
              key={index}
              type="button"
              onClick={() => {
                onAvatarSelect(avatar);
                setIsOpen(false);
              }}
              className={`w-10 h-10 text-2xl rounded-full hover:bg-white/10 transition-colors duration-200 ${
                selectedAvatar === avatar ? 'bg-cyan-500/20 ring-2 ring-cyan-400' : ''
              }`}
            >
              {avatar}
            </button>
          ))}
        </div>
      )}

      {/* Overlay para fechar */}
      {isOpen && (
        <div
          className="fixed inset-0 z-5"
          onClick={() => setIsOpen(false)}
        />
      )}
    </div>
  );
}
