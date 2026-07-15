'use client';

import { useGame } from '@/contexts/GameContext';
import { DEFAULT_AVATAR, MEDAL_EMOJIS } from '@/lib/constants';
import PlayerHeader from './PlayerHeader';
import ScreenLayout from '../shared/ScreenLayout';

export default function Leaderboard() {
  const { leaderboard, isHost, nextQuestion, game, currentQuestion } = useGame();

  const isGameFinished = game?.status === 'finished';

  // TODO: this inline print template has visually diverged from the live UI's
  // redesign (colors, layout) — reconciling them is a design task, not a
  // mechanical refactor, so it's left as-is beyond the constant dedup above.
  const handlePrint = () => {
    // Criar uma nova janela com apenas o conteúdo do leaderboard
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    const printContent = `
      <!DOCTYPE html>
      <html>
        <head>
          <title>ExoGame - Resultado Final</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              margin: 20px;
              background: white;
            }
            .header {
              text-align: center;
              margin-bottom: 30px;
              border-bottom: 2px solid #8B5CF6;
              padding-bottom: 20px;
            }
            .game-info {
              text-align: center;
              margin-bottom: 30px;
              font-size: 14px;
              color: #666;
            }
            .trophy {
              font-size: 48px;
              margin-bottom: 10px;
            }
            .title {
              font-size: 28px;
              font-weight: bold;
              color: #8B5CF6;
              margin-bottom: 10px;
            }
            .subtitle {
              font-size: 16px;
              color: #666;
            }
            .leaderboard {
              max-width: 600px;
              margin: 0 auto;
            }
            .player-row {
              display: flex;
              justify-content: space-between;
              align-items: center;
              padding: 15px 20px;
              margin-bottom: 10px;
              border-radius: 8px;
              border: 1px solid #ddd;
            }
            .winner {
              background: linear-gradient(135deg, #FEF3C7, #FDE68A);
              border-color: #F59E0B;
              font-weight: bold;
            }
            .player-info {
              display: flex;
              align-items: center;
            }
            .avatar {
              font-size: 24px;
              margin-right: 10px;
            }
            .medal {
              width: 30px;
              height: 30px;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              margin-right: 15px;
              background: white;
              font-size: 18px;
            }
            .player-info {
              display: flex;
              align-items: center;
              flex: 1;
            }
            .player-name {
              font-size: 18px;
              font-weight: 600;
            }
            .host-badge {
              margin-left: 10px;
              background: #DBEAFE;
              color: #1E40AF;
              padding: 2px 8px;
              border-radius: 12px;
              font-size: 10px;
              font-weight: bold;
            }
            .score {
              font-size: 20px;
              font-weight: bold;
              color: #8B5CF6;
            }
            .footer {
              text-align: center;
              margin-top: 40px;
              padding-top: 20px;
              border-top: 1px solid #ddd;
              font-size: 12px;
              color: #999;
            }
            @media print {
              body { margin: 0; }
            }
          </style>
        </head>
        <body>
          <div class="header">
            <div class="trophy">🏆</div>
            <div class="title">ExoGame - Resultado Final</div>
            <div class="subtitle">Jogo de Perguntas e Respostas</div>
          </div>
          
          <div class="game-info">
            <p><strong>Código do Jogo:</strong> ${game?.id || 'N/A'}</p>
            <p><strong>Data:</strong> ${new Date().toLocaleDateString('pt-BR')}</p>
            <p><strong>Total de Jogadores:</strong> ${leaderboard.length}</p>
          </div>

          <div class="leaderboard">
            ${leaderboard.map((player, index) => {
              const isWinner = index === 0;

              return `
                <div class="player-row ${isWinner ? 'winner' : ''}">
                  <div class="player-info">
                    <div class="avatar">${player.avatar || DEFAULT_AVATAR}</div>
                    <div class="medal">
                      ${index < 3 ? MEDAL_EMOJIS[index] : index + 1}
                    </div>
                    <div>
                      <span class="player-name">${player.name}</span>
                      ${player.isHost ? '<span class="host-badge">HOST</span>' : ''}
                    </div>
                  </div>
                  <div class="score">${player.score.toLocaleString()} pts</div>
                </div>
              `;
            }).join('')}
          </div>

          <div class="footer">
            <p>Gerado pelo ExoGame em ${new Date().toLocaleString('pt-BR')}</p>
            <p>Obrigado por jogar! 🎮</p>
          </div>
        </body>
      </html>
    `;

    printWindow.document.write(printContent);
    printWindow.document.close();
    
    // Aguardar o carregamento e imprimir
    setTimeout(() => {
      printWindow.print();
      printWindow.close();
    }, 250);
  };

  return (
    <div>
      <PlayerHeader />
      <ScreenLayout maxWidth="max-w-2xl" showHeaderOffset>
          <div className="text-center mb-8">
            <h1 className="font-heading text-3xl font-bold text-white mb-2">
              {isGameFinished ? '🏆 Resultado Final' : '📊 Placar Atual'}
            </h1>
            {currentQuestion && (
              <div className="glass-row rounded-lg p-4 mb-4">
                <p className="text-sm text-white/50 mb-1">Pergunta:</p>
                <p className="font-semibold text-white">{currentQuestion.text}</p>
                {currentQuestion.correctAnswer !== undefined && (
                  <p className="text-sm text-emerald-300 mt-2">
                    ✅ Resposta correta: {String.fromCharCode(65 + currentQuestion.correctAnswer)} - {currentQuestion.options[currentQuestion.correctAnswer]}
                  </p>
                )}
              </div>
            )}
          </div>

          <div className="space-y-3 mb-8">
            {leaderboard.map((player, index) => {
              const isWinner = index === 0 && isGameFinished;

              return (
                <div
                  key={player.id}
                  className={`flex items-center justify-between p-4 rounded-lg ${
                    isWinner
                      ? 'bg-gradient-to-r from-yellow-400/20 to-amber-400/20 border-2 border-yellow-400/40'
                      : index < 3
                      ? 'glass-row'
                      : 'bg-white/[0.03] border border-white/5'
                  }`}
                >
                  <div className="flex items-center">
                    <div className="text-2xl mr-3">{player.avatar || DEFAULT_AVATAR}</div>
                    <div className={`flex items-center justify-center w-8 h-8 rounded-full mr-4 ${
                      index < 3 ? 'bg-white/10' : 'bg-white/5'
                    }`}>
                      {index < 3 ? (
                        <span className="text-lg">{MEDAL_EMOJIS[index]}</span>
                      ) : (
                        <span className="font-bold text-white/60">{index + 1}</span>
                      )}
                    </div>
                    <div>
                      <p className={`font-semibold ${isWinner ? 'text-yellow-300' : 'text-white'}`}>
                        {player.name}
                        {player.isHost && (
                          <span className="ml-2 text-xs bg-cyan-400/20 text-cyan-300 border border-cyan-400/30 px-2 py-1 rounded-full">
                            HOST
                          </span>
                        )}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className={`text-xl font-bold ${isWinner ? 'text-yellow-300' : 'bg-gradient-to-r from-cyan-300 to-purple-300 bg-clip-text text-transparent'}`}>
                      {player.score.toLocaleString()}
                    </p>
                    <p className="text-xs text-white/40">pontos</p>
                  </div>
                </div>
              );
            })}
          </div>

          {isHost && !isGameFinished && (
            <div className="text-center">
              <button
                onClick={nextQuestion}
                className="bg-gradient-to-r from-cyan-400 to-blue-500 hover:from-cyan-300 hover:to-blue-400 text-white font-bold py-3 px-8 rounded-xl transition duration-200 shadow-lg shadow-blue-500/25"
              >
                Próxima Pergunta
              </button>
            </div>
          )}

          {isGameFinished && (
            <div className="text-center">
              <div className="bg-emerald-400/10 border border-emerald-400/30 text-emerald-300 px-4 py-3 rounded-lg mb-4">
                🎉 Jogo finalizado! Obrigado por explorar conosco!
              </div>
              <div className="flex justify-center space-x-4">
                <button
                  onClick={handlePrint}
                  className="bg-white/10 hover:bg-white/20 border border-white/15 text-white font-bold py-3 px-8 rounded-xl transition duration-200 flex items-center"
                >
                  🖨️ Imprimir Resultado
                </button>
                <button
                  onClick={() => window.location.reload()}
                  className="bg-gradient-to-r from-purple-500 to-fuchsia-600 hover:from-purple-400 hover:to-fuchsia-500 text-white font-bold py-3 px-8 rounded-xl transition duration-200 shadow-lg shadow-purple-500/25"
                >
                  Jogar Novamente
                </button>
              </div>
            </div>
          )}

          {!isHost && !isGameFinished && (
            <div className="text-center">
              <div className="animate-pulse">
                <div className="inline-flex items-center text-white/60">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-cyan-400 mr-2"></div>
                  Aguardando próxima pergunta...
                </div>
              </div>
            </div>
          )}
      </ScreenLayout>
    </div>
  );
}
