// SPDX-License-Identifier: GPL-3.0-or-later
// Offline integrity check; this does not certify copyright or legal clearance.
// Usage: node tool/verify_kingdom_provenance.mjs
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const directory = 'assets/characters/kingdoms/';
function read(path) {
  const resolved = resolve(root, path);
  if (relative(root, resolved).startsWith('..')) {
    throw new Error(`Manifest path escapes project: ${path}`);
  }
  return readFileSync(resolved);
}
const json = path => JSON.parse(read(path).toString('utf8'));
function verifyHash(path, expected) {
  if (!/^[0-9a-f]{64}$/.test(expected ?? '')) {
    throw new Error(`Missing or invalid SHA-256 for ${path}`);
  }
  const actual = createHash('sha256').update(read(path)).digest('hex');
  if (actual !== expected) throw new Error(`Recorded SHA-256 mismatch: ${path}`);
}
const initial = json(`${directory}initial-kingdoms-preparation-v1.json`);
for (const [path, hash] of Object.entries(initial.sha256)) verifyHash(path, hash);
const historical = json(`${directory}historical-expansion-prompts-v1.json`);
for (const entry of historical.entries) {
  verifyHash(entry.runtime, entry.runtimeSha256);
  verifyHash(entry.source, entry.sourceSha256);
  if (!entry.prompt?.trim()) throw new Error(`Missing prompt: ${entry.id}`);
}
const legendary = json(`${directory}source/legendary-expansion-prompts-v1.json`);
for (const entry of legendary.entries) {
  verifyHash(entry.finalAsset.path, entry.finalAsset.sha256);
  if (!entry.prompt?.trim()) throw new Error(`Missing prompt: ${entry.id}`);
}
const originalRuntimes = [
  ...initial.assets.map(entry => entry.runtime),
  ...historical.entries.map(entry => entry.runtime),
  ...legendary.entries.map(entry => entry.finalAsset.path),
];
if (originalRuntimes.length !== 27 || new Set(originalRuntimes).size !== 27) {
  throw new Error('Expected 27 distinct newly generated runtime atlases');
}
const orientation = json(`${directory}orientation-standard-v2.json`);
if (orientation.entries?.length !== 27) {
  throw new Error('Expected 27 orientation-standardized runtime atlases');
}
for (const entry of orientation.entries) {
  if (!originalRuntimes.includes(entry.source)) {
    throw new Error(`Orientation source is not a recorded v1 atlas: ${entry.source}`);
  }
  verifyHash(entry.source, entry.sourceSha256);
  verifyHash(entry.runtime, entry.runtimeSha256);
  if (entry.canonicalSourceDirection !== 'near-front/viewer-left') {
    throw new Error(`Unexpected orientation policy: ${entry.runtime}`);
  }
}
const runtimes = orientation.entries.map(entry => entry.runtime);
if (new Set(runtimes).size !== 27) {
  throw new Error('Expected 27 distinct orientation-standardized atlases');
}
const pubspec = read('pubspec.yaml').toString('utf8');
for (const path of runtimes) {
  if (!pubspec.split(/\r?\n/).some(line => line.trim() === `- ${path}`)) {
    throw new Error(`Runtime atlas not explicitly bundled: ${path}`);
  }
  const png = read(path);
  if (png.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a' ||
      png.toString('ascii', 12, 16) !== 'IHDR' ||
      png.readUInt32BE(16) !== 1536 || png.readUInt32BE(20) !== 512 ||
      png[25] !== 6) {
    throw new Error(`Expected 1536x512 RGBA PNG: ${path}`);
  }
}
if (pubspec.split(/\r?\n/).some(line =>
  /^\s*-\s+assets\/characters\/kingdoms\/(?:source\/?)?\s*$/.test(line))) {
  throw new Error('Do not bundle the entire provenance/source directory');
}
console.log('Verified 27 orientation-standardized RGBA atlases, source hashes and explicit asset declarations.');
console.log('Integrity verification is not a copyright or similarity clearance.');
