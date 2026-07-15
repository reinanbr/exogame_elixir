'use client';

import { useState, useEffect } from 'react';
import { useGame } from '@/contexts/GameContext';
import PlayerHeader from './PlayerHeader';
import ScreenLayout from '../shared/ScreenLayout';

const ANSWER_OPTION_COLORS = [
  'from-rose-500 to-pink-600',
  'from-cyan-500 to-blue-600',
  'from-amber-400 to-orange-600',
  'from-emerald-400 to-teal-600',
];

const ANSWER_OPTION_GLOW = [
  'shadow-rose-500/30',
  'shadow-blue-500/30',
  'shadow-orange-500/30',
  'shadow-emerald-500/30',
];

export default function QuestionView() {
  const { currentQuestion, submitAnswer, isHost, showResults, game, answerStats } = useGame();
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [hasAnswered, setHasAnswered] = useState(false);
  const [timeLeft, setTimeLeft] = useState(0);

  useEffect(() => {
    if (currentQuestion && game?.currentQuestionStartTime) {
      setHasAnswered(false);
      setSelectedAnswer(null);
      setTimeLeft(currentQuestion.timeLimit);

      const startTime = new Date(game.currentQuestionStartTime).getTime();
      const timer = setInterval(() => {
        const now = Date.now();
        const elapsed = Math.floor((now - startTime) / 1000);
        const remaining = Math.max(0, currentQuestion.timeLimit - elapsed);

        setTimeLeft(remaining);

        if (remaining === 0) {
          clearInterval(timer);
        }
      }, 1000);

      return () => clearInterval(timer);
    }
  }, [currentQuestion, game?.currentQuestionStartTime]);

  const handleAnswerSelect = (answerIndex: number) => {
    if (hasAnswered || timeLeft === 0 || !currentQuestion) return;

    setSelectedAnswer(answerIndex);
    setHasAnswered(true);
    submitAnswer(currentQuestion.id, answerIndex);
  };

  if (!currentQuestion) {
    return null;
  }

  const progressPercentage = (timeLeft / currentQuestion.timeLimit) * 100;

  return (
    <div>
      <PlayerHeader />
      <ScreenLayout maxWidth="max-w-4xl mx-auto" showHeaderOffset column>
          {/* Timer */}
          <div className="mb-6">
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm font-medium text-white/60">⏳ Tempo restante</span>
              <span className="text-2xl font-bold bg-gradient-to-r from-cyan-300 to-purple-300 bg-clip-text text-transparent">{timeLeft}s</span>
            </div>
            <div className="w-full bg-white/10 rounded-full h-3 overflow-hidden">
              <div
                className={`h-3 rounded-full transition-all duration-1000 ${
                  timeLeft > 5 ? 'bg-gradient-to-r from-emerald-400 to-teal-400' : timeLeft > 2 ? 'bg-gradient-to-r from-amber-400 to-yellow-400' : 'bg-gradient-to-r from-rose-500 to-red-500'
                }`}
                style={{ width: `${progressPercentage}%` }}
              ></div>
            </div>
          </div>

          {/* Estatísticas de Respostas */}
          {answerStats && (
            <div className="mb-6 glass-row rounded-lg p-4">
              <div className="flex justify-between items-center text-sm">
                <span className="text-cyan-300">
                  📡 Respostas: {answerStats.answered}/{answerStats.total}
                </span>
                <span className="text-white/60">
                  {answerStats.pending > 0 ? `${answerStats.pending} aguardando` : 'Todos responderam'}
                </span>
              </div>
              <div className="w-full bg-white/10 rounded-full h-2 mt-2 overflow-hidden">
                <div
                  className="h-2 bg-gradient-to-r from-cyan-400 to-blue-500 rounded-full transition-all duration-500"
                  style={{ width: `${(answerStats.answered / answerStats.total) * 100}%` }}
                ></div>
              </div>
            </div>
          )}

          {/* Question */}
          <div className="text-center mb-8">
            <h2 className="text-2xl md:text-3xl font-bold text-white mb-4">
              {currentQuestion.text}
            </h2>
          </div>

          {/* Answer Options */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
            {currentQuestion.options.map((option, index) => {
              const isSelected = selectedAnswer === index;
              const isDisabled = hasAnswered || timeLeft === 0;

              return (
                <button
                  key={index}
                  onClick={() => handleAnswerSelect(index)}
                  disabled={isDisabled}
                  className={`p-6 rounded-xl text-white font-bold text-lg transition-all duration-200 transform hover:scale-105 shadow-lg ${ANSWER_OPTION_GLOW[index]} ${
                    isSelected
                      ? `bg-gradient-to-r ${ANSWER_OPTION_COLORS[index]} ring-4 ring-white/40 scale-105`
                      : `bg-gradient-to-r ${ANSWER_OPTION_COLORS[index]} hover:shadow-xl`
                  } ${
                    isDisabled && !isSelected ? 'opacity-40 cursor-not-allowed transform-none' : ''
                  }`}
                >
                  <div className="flex items-center justify-center">
                    <span className="mr-3 text-2xl font-black">
                      {String.fromCharCode(65 + index)}
                    </span>
                    <span>{option}</span>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Status */}
          <div className="text-center">
            {hasAnswered && (
              <div className="bg-emerald-400/10 border border-emerald-400/30 text-emerald-300 px-4 py-3 rounded-lg mb-4">
                ✅ Resposta enviada! Aguardando outros exploradores...
              </div>
            )}

            {timeLeft === 0 && !hasAnswered && (
              <div className="bg-rose-500/10 border border-rose-500/30 text-rose-300 px-4 py-3 rounded-lg mb-4">
                ⏰ Tempo esgotado!
              </div>
            )}

            {isHost && (
              <button
                onClick={showResults}
                className="bg-gradient-to-r from-purple-500 to-fuchsia-600 hover:from-purple-400 hover:to-fuchsia-500 text-white font-bold py-3 px-6 rounded-xl transition duration-200 shadow-lg shadow-purple-500/25"
              >
                Mostrar Resultados
              </button>
            )}
          </div>
      </ScreenLayout>
    </div>
  );
}
