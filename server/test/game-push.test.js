import test from 'node:test';
import assert from 'node:assert/strict';
import { GamePushSender } from '../src/game-push.js';

test('FCM v1 sends notification and game routing with server-side OAuth', async () => {
  let request;
  const sender = new GamePushSender({ projectId: 'chess-test', tokenProvider: async () => 'server-oauth',
    fetchImpl: async (url, options) => { request = { url, options }; return { ok: true }; } });
  await sender.send({ token: 'device-token', gameId: 'game-one', title: 'Game ready', body: 'Friend joined.' });
  assert.equal(request.url, 'https://fcm.googleapis.com/v1/projects/chess-test/messages:send');
  assert.equal(request.options.headers.Authorization, 'Bearer server-oauth');
  const message = JSON.parse(request.options.body).message;
  assert.deepEqual(message.data, { gameId: 'game-one' });
  assert.equal(message.notification.body, 'Friend joined.');
  assert.equal(message.android.notification.channel_id, 'online_games');
  assert.equal(message.apns.payload.aps.sound, 'default');
});

test('FCM failures propagate without exposing token content', async () => {
  const sender = new GamePushSender({ projectId: 'chess-test', tokenProvider: async () => 'private-token',
    fetchImpl: async () => ({ ok: false, status: 401 }) });
  await assert.rejects(sender.send({ token: 'device-token', gameId: 'one' }), /FCM delivery failed \(401\)/);
  assert.throws(() => new GamePushSender({ projectId: '../bad' }), /Invalid FCM project/);
});
