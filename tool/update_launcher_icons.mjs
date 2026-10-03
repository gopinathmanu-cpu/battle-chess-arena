// SPDX-License-Identifier: GPL-3.0-or-later
// Regenerate native launcher sizes on macOS, or validate them on any Node host.
// node tool/update_launcher_icons.mjs [--check]
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';

const root = fileURLToPath(new URL('../', import.meta.url));
const source = join(root, 'assets/branding/battle_chess_arena_icon_v7.png');
const ios = join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
const web = join(root, 'web');
let opaqueSource = source;
if (!process.argv.includes('--check') && readFileSync(source)[25] === 6) {
  const exportDirectory = join(root, 'build/icon-export');
  mkdirSync(exportDirectory, { recursive: true });
  opaqueSource = join(exportDirectory, 'opaque-ios.png');
  execFileSync('swift', ['-module-cache-path', join(exportDirectory, 'swift-cache'),
    join(root, 'tool/flatten_launcher_icon.swift'), source, opaqueSource], { stdio: 'inherit' });
}
const targets = new Map();
for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
  targets.set(join(root, `android/app/src/main/res/mipmap-${density}/ic_launcher.png`), size);
}
for (const entry of JSON.parse(readFileSync(join(ios, 'Contents.json'), 'utf8')).images) {
  targets.set(join(ios, entry.filename), Math.round(parseFloat(entry.size) * parseFloat(entry.scale)));
}
for (const [filename, size] of Object.entries({
  'favicon.png': 16,
  'icons/Icon-192.png': 192,
  'icons/Icon-512.png': 512,
  'icons/Icon-maskable-192.png': 192,
  'icons/Icon-maskable-512.png': 512,
})) {
  targets.set(join(web, filename), size);
}
for (const [target, size] of targets) {
  if (!process.argv.includes('--check')) {
    const input = target.startsWith(ios) ? opaqueSource : source;
    execFileSync('sips', ['-z', String(size), String(size), input, '--out', target], { stdio: 'ignore' });
  }
  const png = readFileSync(target);
  if (png.subarray(1, 4).toString() !== 'PNG' || png.readUInt32BE(16) !== size || png.readUInt32BE(20) !== size) {
    throw new Error(`Incorrect PNG dimensions: ${target}`);
  }
  if (target.startsWith(ios) ? png[25] !== 2 : ![2, 6].includes(png[25])) {
    throw new Error(`Invalid launcher format (iOS requires opaque RGB): ${target}`);
  }
}
const digest = path => createHash('sha256').update(readFileSync(path)).digest('hex');
const manifest = Object.fromEntries([source, ...targets.keys()].map(path => [relative(root, path), digest(path)]));
const manifestPath = join(root, 'assets/branding/launcher-icons.manifest.json');
if (process.argv.includes('--check')) {
  if (JSON.stringify(JSON.parse(readFileSync(manifestPath, 'utf8'))) !== JSON.stringify(manifest)) {
    throw new Error('Stale launcher export: regenerate icons from the current master.');
  }
} else {
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
}
console.log(`${targets.size} launcher icons validated (dimensions, Android/web RGB/RGBA, iOS opaque RGB).`);
