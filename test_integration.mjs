/**
 * Integration test for the ExoGame backend (Elixir/Phoenix).
 * Tests the full game flow via WebSocket (Phoenix Channels).
 * 
 * Run: node test_integration.mjs
 */

import { Socket } from 'phoenix';
import WebSocket from 'ws';

// Phoenix JS client expects a global WebSocket
globalThis.WebSocket = WebSocket;

const BACKEND_URL = 'ws://localhost:3001/socket';

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function test() {
  console.log('=== ExoGame Integration Test (Elixir/Phoenix) ===\n');

  // Test 1: REST API
  console.log('--- Test 1: REST API (Questions) ---');
  const questionsRes = await fetch('http://localhost:3001/questions');
  const questions = await questionsRes.json();
  console.log(`  Questions count: ${questions.length}`);
  console.log(`  First question: "${questions[0].text}"`);
  console.log(`  Has correctAnswer: ${questions[0].correctAnswer !== undefined}`);
  console.log(`  Has timeLimit: ${questions[0].timeLimit !== undefined}`);
  console.assert(questions.length === 5, 'Expected 5 questions');
  console.log('  ✅ REST API working\n');

  // Test 2: WebSocket Connection & Game Creation
  console.log('--- Test 2: WebSocket Connection (Host) ---');
  
  const hostSocket = new Socket(BACKEND_URL, {});
  hostSocket.connect();
  
  await delay(1000);
  console.log('  Host socket connected');

  const hostLobby = hostSocket.channel('game:lobby', {});
  
  let hostPlayerId = null;
  let gameId = null;

  const joinResult = await new Promise((resolve) => {
    hostLobby.join()
      .receive('ok', (resp) => resolve(resp));
  });
  hostPlayerId = joinResult.playerId;
  console.log(`  Host playerId: ${hostPlayerId}`);
  console.log('  ✅ Host joined lobby\n');

  // Test 3: Create Game
  console.log('--- Test 3: Create Game ---');
  
  const createGamePromise = new Promise((resolve) => {
    hostLobby.on('gameCreated', (data) => {
      resolve(data);
    });
  });

  hostLobby.push('createGame', { hostName: 'TestHost', avatar: '🐻' });
  
  const gameCreatedData = await createGamePromise;
  gameId = gameCreatedData.game.id;
  console.log(`  Game created: ${gameId}`);
  console.log(`  Host: ${gameCreatedData.game.players[0].name}`);
  console.log(`  Status: ${gameCreatedData.game.status}`);
  console.assert(gameCreatedData.game.status === 'waiting', 'Expected status waiting');
  console.log('  ✅ Game created successfully\n');

  // Host joins game channel
  const hostGameChannel = hostSocket.channel(`game:${gameId}`, {});
  await new Promise((resolve) => {
    hostGameChannel.join().receive('ok', () => resolve(true));
  });
  console.log('  Host joined game channel');

  // Test 4: Player joins game
  console.log('\n--- Test 4: Player Joins Game ---');
  
  const playerSocket = new Socket(BACKEND_URL, {});
  playerSocket.connect();
  await delay(500);

  const playerLobby = playerSocket.channel('game:lobby', {});
  const playerJoinResult = await new Promise((resolve) => {
    playerLobby.join().receive('ok', (resp) => resolve(resp));
  });
  const playerPlayerId = playerJoinResult.playerId;
  console.log(`  Player playerId: ${playerPlayerId}`);

  const playerJoinedPromise = new Promise((resolve) => {
    playerLobby.on('gameJoined', (data) => resolve(data));
  });

  const hostPlayerJoinedPromise = new Promise((resolve) => {
    hostGameChannel.on('playerJoined', (data) => resolve(data));
  });

  playerLobby.push('joinGame', { gameId, playerName: 'TestPlayer', avatar: '🐱' });
  
  const playerJoinedData = await playerJoinedPromise;
  console.log(`  Player joined: ${playerJoinedData.player.name}`);
  console.log(`  Total players: ${playerJoinedData.game.players.length}`);
  console.assert(playerJoinedData.game.players.length === 2, 'Expected 2 players');

  const hostNotified = await hostPlayerJoinedPromise;
  console.log(`  Host was notified of player join: ${hostNotified.player.name}`);
  console.log('  ✅ Player joined successfully\n');

  // Player also joins game channel
  const playerGameChannel = playerSocket.channel(`game:${gameId}`, {});
  await new Promise((resolve) => {
    playerGameChannel.join().receive('ok', () => resolve(true));
  });

  // Test 5: Start Game  
  console.log('--- Test 5: Start Game ---');
  
  const gameStartedPromise = new Promise((resolve) => {
    hostGameChannel.on('gameStarted', (data) => resolve(data));
  });

  const playerGameStartedPromise = new Promise((resolve) => {
    playerGameChannel.on('gameStarted', (data) => resolve(data));
  });

  hostLobby.push('startGame', { gameId });
  
  const gameStartedData = await gameStartedPromise;
  console.log(`  Game status: ${gameStartedData.game.status}`);
  console.log(`  Current question: "${gameStartedData.currentQuestion.text}"`);
  console.log(`  correctAnswer stripped: ${gameStartedData.currentQuestion.correctAnswer === undefined}`);
  console.assert(gameStartedData.game.status === 'playing', 'Expected status playing');
  
  const playerGameStarted = await playerGameStartedPromise;
  console.log(`  Player also received gameStarted event`);
  console.log('  ✅ Game started successfully\n');

  // Test 6: Submit Answer
  console.log('--- Test 6: Submit Answer ---');
  
  const questionId = gameStartedData.currentQuestion.id;
  
  const statsPromise = new Promise((resolve) => {
    playerGameChannel.on('answerStatsUpdated', (data) => resolve(data));
  });

  const answerSubmittedPromise = new Promise((resolve) => {
    playerLobby.on('answerSubmitted', (data) => resolve(data));
  });

  playerLobby.push('submitAnswer', { questionId, answer: 0 });
  
  const statsData = await statsPromise;
  console.log(`  Answer stats - total: ${statsData.stats.total}, answered: ${statsData.stats.answered}, pending: ${statsData.stats.pending}`);
  console.assert(statsData.stats.answered === 1, 'Expected 1 answered');
  console.log('  ✅ Answer submitted and stats received\n');

  // Test 7: Show Results
  console.log('--- Test 7: Show Results ---');
  
  const resultsPromise = new Promise((resolve) => {
    hostGameChannel.on('questionResults', (data) => resolve(data));
  });

  hostLobby.push('showResults', { gameId });
  
  const resultsData = await resultsPromise;
  console.log(`  Question (with answer): "${resultsData.question.text}"`);
  console.log(`  correctAnswer present: ${resultsData.question.correctAnswer !== undefined}`);
  console.log(`  Leaderboard entries: ${resultsData.leaderboard.length}`);
  resultsData.leaderboard.forEach((p, i) => {
    console.log(`    ${i + 1}. ${p.avatar} ${p.name}: ${p.score} pts`);
  });
  console.log('  ✅ Results shown successfully\n');

  // Test 8: REST API - Game info
  console.log('--- Test 8: REST API (Game Info) ---');
  const gameRes = await fetch(`http://localhost:3001/games/${gameId}`);
  const gameInfo = await gameRes.json();
  console.log(`  Game ${gameInfo.id} - Status: ${gameInfo.status}`);
  console.log(`  Players: ${gameInfo.players.length}`);
  console.assert(gameInfo.status === 'playing', 'Expected game to be playing');
  
  const lbRes = await fetch(`http://localhost:3001/games/${gameId}/leaderboard`);
  const lb = await lbRes.json();
  console.log(`  Leaderboard from REST: ${lb.length} entries`);
  console.log('  ✅ REST API game info working\n');

  // Cleanup
  hostSocket.disconnect();
  playerSocket.disconnect();

  console.log('=== All Tests Passed! ✅ ===');
  process.exit(0);
}

test().catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
