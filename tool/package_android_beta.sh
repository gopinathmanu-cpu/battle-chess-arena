#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Run from the repository root after verification. No signing secrets are copied.
set -euo pipefail

beta_version="$(sed -n 's/^version: //p' pubspec.yaml)"
if [[ ! "$beta_version" =~ ^[a-zA-Z0-9.+-]+$ ]]; then
  echo "Invalid or missing pubspec version" >&2
  exit 1
fi
beta_output="build/beta-$beta_version"
beta_validation="${1:-docs/BETA_6_VALIDATION.md}"
case "${2:-all}" in
  all) beta_abis=(arm64-v8a armeabi-v7a x86_64) ;;
  arm64-v8a) beta_abis=(arm64-v8a) ;;
  *) echo "Supported ABI selections: all or arm64-v8a" >&2; exit 1 ;;
esac
test -f "$beta_validation"
if [[ -e "$beta_output" ]]; then
  echo "Refusing to overwrite an existing beta handoff: $beta_output" >&2
  exit 1
fi
for beta_abi in "${beta_abis[@]}"; do
  test -f "build/app/outputs/flutter-apk/app-$beta_abi-release.apk"
done
mkdir -p "$beta_output"
for beta_abi in "${beta_abis[@]}"; do
  cp "build/app/outputs/flutter-apk/app-$beta_abi-release.apk" "$beta_output/battle-chess-arena-$beta_version-$beta_abi.apk"
done
cp docs/DEVICE_VALIDATION_CHECKLIST.md docs/ANDROID_BETA_RELEASE.md "$beta_validation" "$beta_output/"

# Explicit project roots plus excluded local/generated material. Preserve the
# uncommitted source used for this APK rather than archiving only git HEAD.
COPYFILE_DISABLE=1 tar -czf "$beta_output/corresponding-source.tar.gz" \
  --exclude='.git' --exclude='.DS_Store' --exclude='._*' \
  --exclude='.env' --exclude='.env.*' --exclude='key.properties' \
  --exclude='*.jks' --exclude='*.keystore' --exclude='local.properties' \
  --exclude='node_modules' --exclude='build' --exclude='.gradle' \
  --exclude='.cxx' --exclude='.dart_tool' --exclude='.symlinks' \
  --exclude='Pods' --exclude='ephemeral' --exclude='.idea' \
  --exclude='*.iml' --exclude='xcuserdata' --exclude='*.xcuserstate' \
  --exclude='.flutter-plugins*' --exclude='.packages' \
  --exclude='*.log' --exclude='Generated.xcconfig' \
  --exclude='flutter_export_environment.sh' \
  README.md CHANGELOG.md LICENSE COPYING OPEN_SOURCE_POLICY.md THIRD_PARTY_NOTICES.md \
  analysis_options.yaml pubspec.yaml pubspec.lock \
  android ios web lib assets docs test server third_party tool

(
  cd "$beta_output"
  shasum -a 256 ./*.apk corresponding-source.tar.gz ./*.md > SHA256SUMS
)
echo "Beta handoff created: $beta_output"
echo "Review the source archive file list before sharing. No upload was performed."
