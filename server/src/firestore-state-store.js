// SPDX-License-Identifier: GPL-3.0-or-later
import { gzipSync, gunzipSync } from 'node:zlib';

// Small, single-authority deployment checkpoint. CAS prevents a stale container
// from overwriting a newer authority during restart/deployment overlap.
// Server IAM only: never send this document or its credentials to a client.
export class FirestoreStateStore {
  constructor({ projectId, database = '(default)', fetchImpl = fetch, tokenProvider } = {}) {
    if (!/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(projectId ?? '') ||
        !/^(\(default\)|[a-z0-9-]+)$/.test(database)) throw new Error('Invalid Firestore configuration');
    this.fetch = fetchImpl;
    this.database = `projects/${projectId}/databases/${database}`;
    this.name = `${this.database}/documents/serverState/authority-v1`;
    this.tokenProvider = tokenProvider ?? (() => this.metadataToken());
    this.loaded = false;
  }

  async metadataToken() {
    if (this.token && Date.now() < this.tokenExpiresAt) return this.token;
    const response = await this.fetch('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token', {
      headers: { 'Metadata-Flavor': 'Google' }, signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error('Service account credentials unavailable');
    const data = await response.json();
    if (!data.access_token || !data.expires_in) throw new Error('Invalid service account token');
    this.token = data.access_token;
    this.tokenExpiresAt = Date.now() + Math.max(0, data.expires_in - 60) * 1000;
    return this.token;
  }

  async request(path, options = {}) {
    return this.fetch(`https://firestore.googleapis.com/v1/${path}`, {
      ...options, signal: AbortSignal.timeout(10000),
      headers: { Authorization: `Bearer ${await this.tokenProvider()}`, 'Content-Type': 'application/json' },
    });
  }

  async load() {
    const response = await this.request(this.name);
    if (response.status === 404) { this.loaded = true; this.updateTime = null; return null; }
    if (!response.ok) throw new Error(`Firestore load failed (${response.status})`);
    const data = await response.json();
    const saved = JSON.parse(gunzipSync(Buffer.from(data.fields.checkpoint.bytesValue, 'base64'),
      { maxOutputLength: 32 * 1024 * 1024 }).toString());
    this.updateTime = data.updateTime;
    if (!this.updateTime || saved.version !== 1) throw new Error('Invalid Firestore checkpoint');
    this.loaded = true;
    return saved;
  }

  async save(state) {
    if (!this.loaded) throw new Error('Load before writing durable state');
    const bytes = gzipSync(JSON.stringify(state));
    // Stay comfortably below the Firestore 1 MiB document limit. Fail closed,
    // never silently drop old games/profiles to make room.
    if (bytes.length > 900000) throw new Error('Durable checkpoint capacity reached');
    const response = await this.request(`${this.database}/documents:commit`, {
      method: 'POST', body: JSON.stringify({ writes: [{
        update: { name: this.name, fields: { checkpoint: { bytesValue: bytes.toString('base64') } } },
        currentDocument: this.updateTime ? { updateTime: this.updateTime } : { exists: false },
      }] }),
    });
    if (!response.ok) throw new Error(`Firestore save failed (${response.status})`);
    const data = await response.json();
    const updateTime = data.writeResults?.[0]?.updateTime;
    if (!updateTime) throw new Error('Missing Firestore write acknowledgement');
    this.updateTime = updateTime;
  }
}
