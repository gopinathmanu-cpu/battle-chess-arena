// SPDX-License-Identifier: GPL-3.0-or-later
import { randomUUID } from 'node:crypto';
import { MatchError } from './match.js';

export const deletedInviteMessage = 'This invitation has been deleted. Ask your friend to send a new invite.';
export const unavailableInviteMessage = 'This invitation is no longer available. Ask your friend to send a new invite.';
export const expiredInviteMessage = 'This invitation has expired. Ask your friend to send a new invite.';
export const inviteLifetimeMs = 24 * 60 * 60 * 1000;
export const inviteExpiresAt = (createdAt, scheduledAt = null) =>
  Math.max(createdAt + inviteLifetimeMs, scheduledAt === null ? 0 : scheduledAt + 15 * 60 * 1000);

// Like the match store, this reference store is process-local. Missing records
// fail closed after a restart; opening an old URL never creates a new invite.
export class SharedInvites {
  records = new Map();
  constructor({ now = Date.now } = {}) { this.now = now; }

  status(invite) {
    if (['deleted', 'expired'].includes(invite.status)) return invite.status;
    return this.now() >= invite.expiresAt ? 'expired' : invite.status;
  }

  expire() {
    const changed = [];
    for (const invite of this.records.values()) {
      if (invite.status !== 'expired' && this.status(invite) === 'expired') {
        invite.status = 'expired';
        changed.push(invite);
      }
    }
    return changed;
  }

  create(owner, message) {
    const previous = [...this.records.values()].find((item) =>
      item.owner.id === owner.id && item.commandId === message.commandId);
    if (previous) {
      if (previous.fingerprint !== JSON.stringify(message))
        throw new MatchError('COMMAND_ID_REUSED', 'Command ID was already used');
      return previous;
    }
    if (this.records.size >= 1000)
      throw new MatchError('INVITE_LIMIT', 'Invitation limit reached. Please try again later.');
    const createdAt = this.now();
    const invite = {
      id: randomUUID(), owner, commandId: message.commandId,
      fingerprint: JSON.stringify(message), status: 'pending',
      createdAt, expiresAt: inviteExpiresAt(createdAt), baseMs: message.baseMs ?? 600000,
      incrementMs: message.incrementMs ?? 0, clockMode: message.clockMode ?? 'live',
      tossForColors: message.tossForColors ?? false, match: null,
    };
    this.records.set(invite.id, invite);
    return invite;
  }

  requireAvailable(id) {
    const invite = this.records.get(id);
    if (!invite) throw new MatchError('INVITE_UNAVAILABLE', unavailableInviteMessage);
    if (invite.status === 'deleted') throw new MatchError('INVITE_DELETED', deletedInviteMessage);
    if (this.status(invite) === 'expired') throw new MatchError('INVITE_EXPIRED', expiredInviteMessage);
    return invite;
  }

  remove(id, ownerId) {
    const invite = this.records.get(id);
    if (!invite || invite.owner.id !== ownerId)
      throw new MatchError('INVITE_UNAVAILABLE', unavailableInviteMessage);
    // Revoke even a used link without deleting the game or its history.
    invite.status = 'deleted';
    return invite;
  }

  public(invite) {
    return { inviteId: invite.id, avatarName: invite.owner.name,
      status: this.status(invite), createdAt: invite.createdAt, expiresAt: invite.expiresAt };
  }

  list(ownerId) {
    return [...this.records.values()]
      .filter((invite) => invite.owner.id === ownerId && invite.status !== 'deleted')
      .reverse().map((invite) => this.public(invite));
  }
}

const escapeHtml = (value) => String(value).replace(/[&<>"']/g,
  (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);

// Public certificate fingerprint of the established, directly distributed APK.
// Add the Play App Signing certificate here if a Play-signed release is shipped.
export const androidAssetLinks = [{
  relation: ['delegate_permission/common.handle_all_urls'],
  target: { namespace: 'android_app', package_name: 'com.manugopinath.battlechessarena',
    sha256_cert_fingerprints: ['1D:AA:38:3A:6D:68:69:6B:85:98:E9:14:4E:51:A0:6D:2A:7C:EB:A1:06:5A:14:BC:74:2B:DC:74:7E:F3:AF:51'] },
}];

export function serveInvitePage(request, response, store) {
  if (!['GET', 'HEAD'].includes(request.method)) return false;
  const path = new URL(request.url, 'http://localhost').pathname;
  if (path === '/.well-known/assetlinks.json') {
    response.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-cache' });
    response.end(request.method === 'HEAD' ? undefined : JSON.stringify(androidAssetLinks));
    return true;
  }
  const found = /^\/invite\/([a-zA-Z0-9_-]{1,80})$/.exec(path);
  if (!found) return false;
  const invite = store.records.get(found[1]);
  const status = invite ? store.status(invite) : null;
  const available = invite && !['deleted', 'expired'].includes(status);
  const name = escapeHtml(invite?.owner.name ?? 'Your friend');
  const message = status === 'deleted' ? deletedInviteMessage : status === 'expired' ? expiredInviteMessage : unavailableInviteMessage;
  const body = available
    ? `<p>${name} invited you to play chess.</p><p><a href="battlechessarena://invite?invite=${encodeURIComponent(invite.id)}">Open Battle Chess Arena</a></p><p>If the app does not open, open Play Online, search for the Avatar name <strong>${name}</strong>, and send them an invite to play.</p><p>The app must be installed. Each link admits one opponent and expires 24 hours after creation.</p><p>Expires: ${escapeHtml(new Date(invite.expiresAt).toUTCString())}</p>`
    : `<p>${message}</p>`;
  response.writeHead(available ? 200 : invite ? 410 : 404, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store, max-age=0',
    'x-content-type-options': 'nosniff', 'referrer-policy': 'no-referrer',
    'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
  });
  response.end(request.method === 'HEAD' ? undefined : `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Battle Chess Arena invitation</title><style>body{font:18px system-ui;max-width:36rem;margin:3rem auto;padding:1rem;line-height:1.6;background:#141927;color:#fff}a{display:inline-block;background:#f2bc57;color:#151923;padding:12px 18px;border-radius:12px;font-weight:bold}h1{font-size:1.6rem}</style><h1>${available ? 'Your chess invitation' : 'Invitation unavailable'}</h1>${body}</html>`);
  return true;
}
