// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { Match } from '../src/match.js';
import { validateMessage } from '../src/protocol.js';
import { createMatchServer } from '../src/server.js';
import { FirestoreStateStore } from '../src/firestore-state-store.js';
const day = 86400000;
const daily = { clockMode: 'daily', baseMs: day, incrementMs: 0 };

test('Daily resets only on a legal move; retries and restart keep the deadline', () => {
  const game = new Match(daily);
  game.joinBlack(1000);
  const command = { type: 'move', commandId: 'first', round: 1, ply: 0,
    move: { from: 'e2', to: 'e4' } };
  assert.equal(game.snapshot(1000 + day / 2).clocks.w, day / 2);
  assert.equal(game.command(game.whiteToken, command, 1000 + day / 2).accepted, true);
  assert.deepEqual(game.remaining, { w: day, b: day });
  const deadline = 1000 + day * 1.5;
  const players = new Map(Object.values(game.players).map(p => [p.id, p]));
  const restored = Match.restore(JSON.parse(JSON.stringify(game.checkpoint())), players);
  assert.equal(restored.snapshot(deadline - 5000).turnDeadlineEpochMs, deadline);
  assert.equal(restored.command(restored.whiteToken, command, deadline - 4000).duplicate, true);
  assert.equal(restored.command(restored.tokens.b, { ...command, commandId: 'illegal', ply: 1,
    move: { from: 'a7', to: 'a4' } }, deadline - 3000).accepted, false);
  assert.equal(restored.snapshot(deadline - 1).clocks.b, 1);
  const expired = restored.command(restored.tokens.b, { ...command, commandId: 'too-late', ply: 1,
    move: { from: 'e7', to: 'e5' } }, deadline);
  assert.equal(expired.accepted, false);
  assert.equal(restored.status, 'complete');
  assert.equal(restored.result.winner, 'w');
  assert.deepEqual(restored.chess.history(), ['e4']);
});

test('Daily validation forbids increments, untimed mode, arbitrary day lengths, quick match', () => {
  assert.throws(() => new Match({ ...daily, incrementMs: 10000 }));
  assert.throws(() => new Match({ ...daily, timed: false }));
  assert.throws(() => new Match({ ...daily, baseMs: 900000 }));
  const message = { type: 'send_invite', opponentName: 'Friend', commandId: 'invite', ...daily };
  assert.equal(validateMessage(message).clockMode, 'daily');
  assert.throws(() => validateMessage({ ...message, timed: false }));
  assert.throws(() => validateMessage({ type: 'quick_match', commandId: 'q', ...daily }));
});

test('Daily rematch starts a fresh full allowance for White', () => {
  const game = new Match(daily);
  game.joinBlack(1000);
  game.command(game.whiteToken, { type: 'resign', commandId: 'r', round: 1 }, 2000);
  for (const side of ['w', 'b']) game.command(game.tokens[side],
    { type: 'rematch', commandId: `again-${side}`, round: 1 }, 5000);
  assert.equal(game.round, 2);
  assert.equal(game.snapshot(5000).turnDeadlineEpochMs, 5000 + day);
});

async function client(app, name, token) {
  const socket = new WebSocket(`ws://127.0.0.1:${app.server.address().port}`);
  const frames = [];
  socket.on('message', raw => frames.push(JSON.parse(raw)));
  const next = async (type) => {
    const end = Date.now() + 3000;
    while (Date.now() < end) {
      const index = frames.findIndex(frame => frame.type === type);
      if (index >= 0) return frames.splice(index, 1)[0];
      await new Promise(resolve => setTimeout(resolve, 5));
    }
    throw new Error(`Missing ${type}: ${JSON.stringify(frames)}`);
  };
  await once(socket, 'open');
  const connected = await next('connected');
  const send = message => socket.send(JSON.stringify(message));
  send({ type: 'register_player', commandId: 'register', name, avatarId: 'crown',
    ...(token ? { playerToken: token } : {}) });
  const profile = await next('player_registered');
  return { socket, next, send, profile, connected, frames };
}

test('Daily named invitations, profiles, seats and deadlines survive server restart', async t => {
  let wall = 1800000000000;
  const store = { saved: null, async save(value) { this.saved = structuredClone(value); } };
  const start = async () => {
    const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000,
      now: () => wall, inviteNow: () => wall, stateStore: store, initialState: store.saved });
    await once(app.server, 'listening');
    return app;
  };
  let app = await start();
  t.after(() => app.close());
  const alice = await client(app, 'Alice');
  const bob = await client(app, 'Bobby');
  assert.equal(alice.profile.credits, 300);
  assert.ok(alice.connected.capabilities.includes('daily_games'));
  alice.send({ type: 'send_invite', commandId: 'invite', opponentName: 'Bobby', ...daily });
  const invitation = (await bob.next('invite_updated')).invite;
  assert.equal(invitation.clockMode, 'daily');
  bob.send({ type: 'respond_invite', commandId: 'accept', inviteId: invitation.inviteId, accept: true });
  let update;
  do { update = (await bob.next('invite_updated')).invite; } while (!update.game);
  const id = update.game.gameId;
  const deadline = update.game.state.turnDeadlineEpochMs;
  assert.equal(deadline, wall + day);
  assert.equal(app.profiles.get('alice').creditAccount.bonusBalance, 297);
  assert.equal(app.profiles.get('bobby').creditAccount.bonusBalance, 297);
  assert.ok(store.saved.games.some(game => game.id === id));
  await app.close();
  wall += day - 1000;
  app = await start();
  const returning = await client(app, 'Alice', alice.profile.playerToken);
  returning.send({ type: 'list_games' });
  const resumed = (await returning.next('active_games')).games[0];
  assert.equal(resumed.gameId, id);
  assert.equal(resumed.state.clocks.w, 1000);
  assert.equal(resumed.state.turnDeadlineEpochMs, deadline);
  returning.send({ type: 'resume_game', gameId: id, seatToken: resumed.seatToken });
  await returning.next('seat_resumed');
  wall += 1000;
  await app.tick();
  const final = (await returning.next('game_state')).state;
  assert.equal(final.result.reason, 'timeout');
  assert.equal(store.saved.games.find(game => game.id === id).result.reason, 'timeout');
  assert.equal(app.profiles.get('bobby').points, 3);
});

test('Daily is rejected without a durable store; Rapid shared invites carry increments', async t => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const alice = await client(app, 'Alice');
  const bob = await client(app, 'Bobby');
  assert.equal(alice.connected.capabilities.includes('daily_games'), false);
  alice.send({ type: 'create_shared_invite', commandId: 'daily', ...daily });
  assert.equal((await alice.next('error')).code, 'DAILY_UNAVAILABLE');
  alice.send({ type: 'create_shared_invite', commandId: 'rapid',
    baseMs: 900000, incrementMs: 10000, clockMode: 'live' });
  const invitation = (await alice.next('shared_invite_created')).invite;
  bob.send({ type: 'open_shared_invite', commandId: 'open', inviteId: invitation.inviteId });
  assert.equal((await bob.next('seat_joined')).state.incrementMs, 10000);
});

test('Firestore checkpoints use create/update preconditions and round trip without tokens in URLs', async () => {
  let document = null;
  let revision = 0;
  const fetchImpl = async (url, options) => {
    assert.equal(options.headers.Authorization, 'Bearer test-token');
    assert.equal(url.includes('test-token'), false);
    if (options.method !== 'POST') return new Response(document ? JSON.stringify(document) : '',
      { status: document ? 200 : 404 });
    const write = JSON.parse(options.body).writes[0];
    assert.deepEqual(write.currentDocument, revision ? { updateTime: `revision-${revision}` } : { exists: false });
    document = { ...write.update, updateTime: `revision-${++revision}` };
    return Response.json({ writeResults: [{ updateTime: document.updateTime }] });
  };
  const store = new FirestoreStateStore({ projectId: 'test-project', fetchImpl,
    tokenProvider: async () => 'test-token' });
  assert.equal(await store.load(), null);
  await store.save({ version: 1, value: 'first' });
  await store.save({ version: 1, value: 'second' });
  assert.deepEqual(await store.load(), { version: 1, value: 'second' });
});

test('Storage failure never acknowledges an invitation or advertises healthy state', async t => {
  let fail = false;
  const store = { async save() { if (fail) throw new Error('offline'); } };
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, stateStore: store });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const alice = await client(app, 'Alice');
  fail = true;
  const closed = once(alice.socket, 'close');
  alice.send({ type: 'create_shared_invite', commandId: 'lost', ...daily });
  await closed;
  assert.equal(alice.frames.some(frame => frame.type === 'shared_invite_created'), false);
  const response = await fetch(`http://127.0.0.1:${app.server.address().port}/health`);
  assert.equal(response.status, 503);
});

test('Firestore load/write failures do not reset a checkpoint or retry a stale write', async () => {
  let calls = 0;
  const store = new FirestoreStateStore({ projectId: 'test-project',
    tokenProvider: async () => 'test', fetchImpl: async () => {
      calls++;
      return new Response('', { status: 503 });
    } });
  await assert.rejects(store.load(), /load failed/);
  await assert.rejects(store.save({ version: 1 }), /Load before/);
  assert.equal(calls, 1);
  store.loaded = true;
  store.updateTime = 'original';
  await assert.rejects(store.save({ version: 1 }), /save failed/);
  assert.equal(store.updateTime, 'original');
  assert.equal(calls, 2);
});

test('credit balances and ledger survive restart; resume is free and later login refills only to 300', async t => {
  let wall = Date.UTC(2026, 8, 26, 12);
  const store = { saved: null, async save(value) { this.saved = structuredClone(value); } };
  const start = async () => {
    const instance = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000,
      now: () => wall, creditNow: () => wall, stateStore: store, initialState: store.saved });
    await once(instance.server, 'listening');
    return instance;
  };
  let app = await start();
  t.after(() => app.close());
  const alice = await client(app, 'Wallet Alice');
  const bob = await client(app, 'Wallet Bobby');
  assert.equal(alice.profile.credits, 300);
  alice.send({ type: 'quick_match', commandId: 'wallet-wait' });
  const waiting = await alice.next('matchmaking_waiting');
  assert.equal(waiting.credits, 300);
  bob.send({ type: 'quick_match', commandId: 'wallet-pair' });
  const paired = await bob.next('match_found');
  assert.equal(paired.credits, 298);
  assert.equal(app.profiles.get('wallet alice').creditAccount.bonusBalance, 298);
  assert.equal(app.profiles.get('wallet bobby').creditAccount.bonusBalance, 298);
  assert.equal(store.saved.players.find(player => player.name === 'Wallet Alice')
    .creditAccount.bonusBalance, 298);

  await app.close();
  app = await start();
  const returning = await client(app, 'Wallet Alice', alice.profile.playerToken);
  assert.equal(returning.profile.credits, 298);
  returning.send({ type: 'list_games' });
  const active = (await returning.next('active_games')).games[0];
  assert.equal(active.gameId, paired.gameId);
  returning.send({ type: 'resume_game', gameId: active.gameId, seatToken: active.seatToken });
  const resumed = await returning.next('seat_resumed');
  assert.equal(resumed.credits, 298);
  assert.equal(app.profiles.get('wallet alice').creditAccount.bonusBalance, 298);

  wall += day;
  const tomorrow = await client(app, 'Wallet Alice', alice.profile.playerToken);
  assert.equal(tomorrow.profile.credits, 300);
  const account = await tomorrow.next('credit_balance');
  assert.equal(account.account.bonusCredits, 300);
  assert.equal(account.account.recentTransactions[0].type, 'daily_login');
  assert.equal(account.account.recentTransactions[0].delta, 2);
  assert.equal(store.saved.players.find(player => player.name === 'Wallet Alice')
    .creditAccount.bonusBalance, 300);
});
