// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { validateMessage } from '../src/protocol.js';
import { createMatchServer } from '../src/server.js';

const defaultId = 'custom-v1-020321000000';
const maximumId = 'custom-v1-1337b9455577';
const maxima = [1, 3, 3, 7, 11, 9, 4, 5, 5, 5, 7, 7];
const profile = (avatarId, type = 'register_player') => ({
  type, commandId: 'avatar-test', name: 'Avatar Tester', avatarId,
});

test('every custom-avatar category accepts exactly its v1 range', () => {
  for (const type of ['register_player', 'update_player']) {
    assert.equal(validateMessage(profile(defaultId, type)).avatarId, defaultId);
    assert.equal(validateMessage(profile(maximumId, type)).avatarId, maximumId);
    for (let field = 0; field < maxima.length; field++) {
      for (let option = 0; option < 36; option++) {
        const digits = Array(12).fill('0');
        digits[field] = option.toString(36);
        const id = `custom-v1-${digits.join('')}`;
        if (option <= maxima[field]) {
          assert.equal(validateMessage(profile(id, type)).avatarId, id);
        } else {
          assert.throws(() => validateMessage(profile(id, type)), { code: 'INVALID_MESSAGE' });
        }
      }
    }
  }
});

test('malformed custom-avatar payloads are rejected without broadening legacy IDs', () => {
  for (const id of [
    '', null, 12, {}, [], 'custom-v2-020321000000', 'CUSTOM-v1-020321000000',
    'custom-v1-1337B9455577', 'custom-v1-02032100000', 'custom-v1-0203210000000',
    ` ${defaultId}`, `${defaultId} `, `${defaultId}\n`, `${defaultId}\r\n`,
    'custom-v1-02032100000\0', 'custom-v1-02032100000/',
    'custom-v1-02032100000é', 'custom-v1-02032100000😀',
    `custom-v1-${'0'.repeat(10000)}`, 'avatar-00', 'avatar-51', 'bot_amina',
  ]) {
    assert.throws(() => validateMessage(profile(id)), { code: 'INVALID_MESSAGE' });
  }
  for (const id of ['crown', 'knight', 'mage', 'dragon', 'robot', 'ranger', 'sun', 'moon']) {
    assert.equal(validateMessage(profile(id)).avatarId, id);
  }
  for (let index = 1; index <= 50; index++) {
    const id = `avatar-${String(index).padStart(2, '0')}`;
    assert.equal(validateMessage(profile(id)).avatarId, id);
  }
});

async function connect(url) {
  const socket = new WebSocket(url);
  const inbox = [];
  const waiters = [];
  socket.on('message', (raw) => {
    const message = JSON.parse(raw);
    const index = waiters.findIndex((waiter) => waiter.predicate(message));
    if (index < 0) inbox.push(message);
    else waiters.splice(index, 1)[0].resolve(message);
  });
  await once(socket, 'open');
  return {
    send: (message) => socket.send(JSON.stringify(message)),
    next(predicate) {
      const index = inbox.findIndex(predicate);
      if (index >= 0) return Promise.resolve(inbox.splice(index, 1)[0]);
      return new Promise((resolve, reject) => {
        const waiter = { predicate, resolve: (message) => { clearTimeout(timer); resolve(message); } };
        const timer = setTimeout(() => {
          const index = waiters.indexOf(waiter);
          if (index >= 0) waiters.splice(index, 1);
          reject(new Error('Timed out waiting for custom-avatar response'));
        }, 3000);
        waiters.push(waiter);
      });
    },
  };
}

test('custom avatars register, update, reconnect and travel through public match surfaces', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const creator = await connect(url);
  const handshake = await creator.next((message) => message.type === 'connected');
  assert.equal(handshake.protocolVersion, 4);
  assert.ok(handshake.capabilities.includes('custom_avatars'));
  creator.send({ ...profile(defaultId), name: 'Custom Creator' });
  const registered = await creator.next((message) => message.type === 'player_registered');
  assert.equal(registered.avatarId, defaultId);
  creator.send({ ...profile(maximumId, 'update_player'), commandId: 'edit-custom', name: 'Custom Creator' });
  const updated = await creator.next((message) => message.type === 'player_updated');
  assert.equal(updated.avatarId, maximumId);
  assert.equal(updated.playerToken, registered.playerToken);

  const friend = await connect(url);
  friend.send({ ...profile('avatar-50'), name: 'Preset Friend' });
  await friend.next((message) => message.type === 'player_registered');
  friend.send({ type: 'find_player', query: 'Custom Creator' });
  assert.equal((await friend.next((message) => message.type === 'player_found')).player.avatarId, maximumId);
  friend.send({ type: 'leaderboard' });
  const leaders = (await friend.next((message) => message.type === 'leaderboard')).leaders;
  assert.equal(leaders.find((player) => player.name === 'Custom Creator').avatarId, maximumId);
  assert.equal(leaders.find((player) => player.name === 'Preset Friend').avatarId, 'avatar-50');

  creator.send({ type: 'send_invite', commandId: 'custom-invite', opponentName: 'Preset Friend' });
  const invite = (await friend.next((message) => message.type === 'invite_updated')).invite;
  assert.equal(invite.sender.avatarId, maximumId);
  assert.equal(invite.recipient.avatarId, 'avatar-50');
  friend.send({ type: 'respond_invite', commandId: 'accept-custom', inviteId: invite.inviteId, accept: true });
  const accepted = (await friend.next((message) => message.type === 'invite_updated' && message.invite.status === 'accepted')).invite;
  assert.equal(accepted.game.state.players.w.avatarId, maximumId);
  assert.equal(accepted.game.state.players.b.avatarId, 'avatar-50');
  creator.send({ type: 'list_games' });
  const games = (await creator.next((message) => message.type === 'active_games')).games;
  assert.equal(games[0].state.players.w.avatarId, maximumId);

  const reconnected = await connect(url);
  reconnected.send({ ...profile(maximumId), name: 'Custom Creator', playerToken: registered.playerToken });
  const restored = await reconnected.next((message) => message.type === 'player_registered');
  assert.equal(restored.playerToken, registered.playerToken);
  assert.equal(restored.avatarId, maximumId);
});

test('rejected custom-avatar edits leave stored and public profiles unchanged', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const client = await connect(`ws://127.0.0.1:${app.server.address().port}`);
  client.send(profile(defaultId));
  await client.next((message) => message.type === 'player_registered');
  for (const [index, invalid] of ['custom-v1-200000000000', `${maximumId}\n`, 'custom-v1-0000c0000000'].entries()) {
    client.send({ ...profile(invalid, 'update_player'), commandId: `bad-avatar-${index}` });
    assert.equal((await client.next((message) => message.type === 'error')).code, 'INVALID_MESSAGE');
  }
  client.send({ type: 'leaderboard' });
  const leader = (await client.next((message) => message.type === 'leaderboard')).leaders[0];
  assert.equal(leader.avatarId, defaultId);
  assert.equal(app.profiles.size, 1);
});

test('keyboard punctuation works across avatar registration, editing, discovery and invites', () => {
  for (let code = 33; code <= 126; code++) {
    const name = `${String.fromCharCode(code)}Knight`;
    for (const type of ['register_player', 'update_player']) {
      assert.equal(validateMessage({...profile(defaultId, type), name}).name, name);
    }
    assert.equal(validateMessage({type: 'find_player', query: name}).query, name);
    assert.deepEqual(validateMessage({type: 'presence', names: [name]}).names, [name]);
    assert.equal(validateMessage({type: 'send_invite', commandId: 'invite', opponentName: name}).opponentName, name);
  }
  for (const name of ['ab', 'A'.repeat(21), 'Knight\u0000', 'Knight\u007f', 'Knight\n']) {
    assert.throws(() => validateMessage({...profile(defaultId), name}), {code: 'INVALID_MESSAGE'});
    assert.throws(() => validateMessage({type: 'presence', names: [name]}), {code: 'INVALID_MESSAGE'});
  }
});

test('symbol names remain unique on creation and editing', async (t) => {
  const app = createMatchServer({port: 0, host: '127.0.0.1', tickMs: 60_000});
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const owner = await connect(url);
  owner.send({...profile(defaultId), name: '@Nova#42'});
  const registered = await owner.next(message => message.type === 'player_registered');
  const other = await connect(url);
  other.send({...profile(defaultId), name: '@nova#42'});
  assert.equal((await other.next(message => message.type === 'error')).code, 'AVATAR_NAME_TAKEN');
  other.send({...profile(defaultId), commandId: 'own-name', name: 'Other#Knight'});
  await other.next(message => message.type === 'player_registered');
  other.send({...profile(maximumId, 'update_player'), commandId: 'taken-edit', name: '@NOVA#42'});
  assert.equal((await other.next(message => message.type === 'error')).code, 'AVATAR_NAME_TAKEN');
  owner.send({...profile(maximumId, 'update_player'), commandId: 'own-edit', name: '@NOVA#42'});
  const updated = await owner.next(message => message.type === 'player_updated');
  assert.equal(updated.playerToken, registered.playerToken);
  owner.send({type: 'find_player', query: 'Other#Knight'});
  assert.equal((await owner.next(message => message.type === 'player_found')).player.avatarId, defaultId);
});
