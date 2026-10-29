#!/usr/bin/env bash
#
# Builds the `standalone-server` binary so the Tauri bundler can find it.
#
# Why this is needed: the Tauri CLI enumerates every [[bin]] target declared in
# Cargo.toml and expects each one to exist in the target directory at bundling
# time. src-tauri/Cargo.toml declares `standalone-server`, and its
# `required-features = ["standalone"]` does NOT exclude it from that list — so a
# normal `tauri build` (which uses the default `tauri-mode` features) compiles
# only the app binary and then fails with:
#
#   failed to bundle project: Failed to copy binary from ".../standalone-server":
#   does not exist
#
# Pre-building it is the same workaround the Windows release job uses. The
# binary ends up copied inside the bundle, which is harmless.
#
# Usage:
#   bash scripts/prebuild-standalone-server.sh universal   # for --target universal-apple-darwin
#   bash scripts/prebuild-standalone-server.sh native      # for a plain host build
#
set -euo pipefail

cd "$(dirname "$0")/../src-tauri"

MODE="${1:-native}"
BIN=standalone-server
# The standalone server is a different feature set from the app: no Tauri at all.
FEATURES=(--bin "$BIN" --no-default-features --features standalone --release)

case "$MODE" in
  native)
    echo "==> Building $BIN for this host"
    cargo build "${FEATURES[@]}"
    OUT="target/release/$BIN"
    ;;

  universal)
    # A universal app bundle needs a universal sidecar; the bundler looks for it
    # under the universal target directory, which cargo never creates itself.
    echo "==> Building $BIN for aarch64-apple-darwin"
    cargo build "${FEATURES[@]}" --target aarch64-apple-darwin
    echo "==> Building $BIN for x86_64-apple-darwin"
    cargo build "${FEATURES[@]}" --target x86_64-apple-darwin

    OUT="target/universal-apple-darwin/release/$BIN"
    mkdir -p "$(dirname "$OUT")"
    echo "==> Merging both slices with lipo"
    lipo -create -output "$OUT" \
      "target/aarch64-apple-darwin/release/$BIN" \
      "target/x86_64-apple-darwin/release/$BIN"
    ;;

  *)
    echo "error: unknown mode '$MODE' (expected 'native' or 'universal')" >&2
    exit 1
    ;;
esac

[ -f "$OUT" ] || { echo "error: expected $BIN at $OUT but it is missing" >&2; exit 1; }

echo "==> Ready: src-tauri/$OUT"
command -v lipo >/dev/null && lipo -archs "$OUT" | sed 's/^/    architectures: /' || true
