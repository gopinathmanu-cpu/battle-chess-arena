// SPDX-License-Identifier: GPL-3.0-or-later
import { Match } from './match.js';
import { ensureCreditAccount } from './credits.js';

export function checkpoint({ profiles, games, invites, sharedInvites, awardedResults }) {
  const players = new Map([...profiles.values()].map(player => [player.id, player]));
  for (const game of games.values()) {
    for (const player of Object.values(game.players)) if (player) players.set(player.id, player);
  }
  return {
    version: 1,
    profiles: [...profiles].map(([key, player]) => [key, player.id]),
    players: [...players.values()].map(({ sockets, ...player }) => player),
    games: [...games.values()].map(game => game.checkpoint()),
    awardedResults: [...awardedResults],
    invites: [...invites.values()].map(({ sender, recipient, awaiting, hiddenFor, game, ...invite }) => ({
      ...invite, senderId: sender.id, recipientId: recipient.id, awaitingId: awaiting?.id,
      hiddenFor: [...hiddenFor], gameId: game?.match.id,
    })),
    sharedInvites: [...sharedInvites.records.values()].map(({ owner, match, ...invite }) => ({
      ...invite, ownerId: owner.id, gameId: match?.id,
    })),
  };
}

export function restoreCheckpoint(saved, target, { creditNow = Date.now } = {}) {
  if (!saved) return;
  if (saved.version !== 1) throw new Error('Unsupported durable checkpoint');
  const players = new Map(saved.players.map(player => [player.id, { ...player, sockets: new Set() }]));
  for (const [key, id] of saved.profiles) {
    if (!players.has(id)) throw new Error('Missing durable profile');
    target.profiles.set(key, players.get(id));
  }
  // Missing accounts are valid pre-credit checkpoints. They receive the one
  // deterministic welcome wallet; malformed wallet data fails startup closed.
  for (const player of new Set(target.profiles.values()))
    ensureCreditAccount(player, creditNow());
  for (const state of saved.games) target.games.set(state.id, Match.restore(state, players));
  for (const key of saved.awardedResults) target.awardedResults.add(key);
  for (const { senderId, recipientId, awaitingId, gameId, hiddenFor, ...invite } of saved.invites) {
    const match = gameId ? target.games.get(gameId) : null;
    target.invites.set(invite.id, { ...invite, sender: players.get(senderId),
      recipient: players.get(recipientId), awaiting: players.get(awaitingId) ?? null,
      hiddenFor: new Set(hiddenFor), game: match ? { match, tokens: { ...match.tokens } } : null });
  }
  for (const { ownerId, gameId, ...invite } of saved.sharedInvites) {
    target.sharedInvites.records.set(invite.id, { ...invite, owner: players.get(ownerId),
      match: gameId ? target.games.get(gameId) : null });
  }
}
