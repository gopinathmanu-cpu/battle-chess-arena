// SPDX-License-Identifier: GPL-3.0-or-later
/// FCM HTTP v1; credentials stay on the server (Cloud Run service identity).
export class GamePushSender {
  constructor({ projectId, fetchImpl = fetch, tokenProvider } = {}) {
    if (!/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(projectId ?? '')) throw new Error('Invalid FCM project ID');
    this.projectId = projectId;
    this.fetch = fetchImpl;
    this.tokenProvider = tokenProvider ?? (() => this.metadataToken());
  }
  async metadataToken() {
    if (this.token && Date.now() < this.expiresAt) return this.token;
    const response = await this.fetch('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token', {
      headers: { 'Metadata-Flavor': 'Google' }, signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error('FCM credentials unavailable');
    const data = await response.json();
    if (!data.access_token || !data.expires_in) throw new Error('Invalid FCM credentials');
    this.token = data.access_token;
    this.expiresAt = Date.now() + Math.max(0, data.expires_in - 60) * 1000;
    return this.token;
  }
  async send({ token, gameId, title, body }) {
    const response = await this.fetch(`https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`, {
      method: 'POST', signal: AbortSignal.timeout(10000),
      headers: { Authorization: `Bearer ${await this.tokenProvider()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: {
        token, notification: { title, body }, data: { gameId },
        android: { priority: 'high', collapse_key: gameId,
          notification: { channel_id: 'online_games', sound: 'default' } },
        apns: { headers: { 'apns-collapse-id': gameId }, payload: { aps: { sound: 'default' } } },
      } }),
    });
    if (!response.ok) throw new Error(`FCM delivery failed (${response.status})`);
  }
}
