#!/usr/bin/env bash
#
# Builds the app natively for macOS and leaves you with an installable .dmg.
#
# This is the direct-download build (Hardened Runtime, self-updater enabled) —
# the same thing CI produces. For the Mac App Store variant use
# scripts/build-macos-appstore.sh instead.
#
# Usage:
#   bash scripts/build-macos.sh            # universal: Apple Silicon + Intel
#   bash scripts/build-macos.sh --native   # only this Mac's architecture (faster)
#
set -euo pipefail

cd "$(dirname "$0")/.."

die() { printf '\nerror: %s\n' "$1" >&2; exit 1; }
step() { printf '\n==> %s\n' "$1"; }

UNIVERSAL=1
[ "${1:-}" = "--native" ] && UNIVERSAL=0

# --- prerequisites --------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "This builds a macOS app, so it has to run on a Mac.
       On other systems use the 'Build macOS app' GitHub Actions workflow."

xcode-select -p >/dev/null 2>&1 || die "Xcode command line tools are missing. Install them with:
         xcode-select --install
       then re-run this script."

command -v node >/dev/null || die "Node.js is not installed. Install Node 20+ from https://nodejs.org
       or with Homebrew: brew install node"

NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
[ "$NODE_MAJOR" -ge 18 ] || die "Node $NODE_MAJOR is too old; this project needs Node 18 or newer (20 recommended)."

if ! command -v cargo >/dev/null; then
  die "Rust is not installed. Install it with:
         curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
       then open a new terminal and re-run this script."
fi

step "Toolchain"
echo "    macOS  $(sw_vers -productVersion)"
echo "    Node   $(node --version)"
echo "    Rust   $(rustc --version)"

if [ "$UNIVERSAL" = "1" ]; then
  step "Adding Rust targets for a universal build"
  rustup target add aarch64-apple-darwin x86_64-apple-darwin
fi

step "Installing dependencies (this is cached after the first run)"
npm ci

step "Building — the first build compiles the Rust core and takes a while"
if [ "$UNIVERSAL" = "1" ]; then
  npm run tauri:build:macos:universal
  BUNDLE="src-tauri/target/universal-apple-darwin/release/bundle"
else
  npm run tauri:build:macos
  BUNDLE="src-tauri/target/release/bundle"
fi

DMG=$(find "$BUNDLE/dmg" -maxdepth 1 -name '*.dmg' 2>/dev/null | head -1 || true)
APP=$(find "$BUNDLE/macos" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)
[ -n "$APP" ] || die "The build finished but produced no .app bundle under $BUNDLE"

step "Result"
BIN="$APP/Contents/MacOS/$(basename "$APP" .app)"
[ -f "$BIN" ] && echo "    Architectures: $(lipo -archs "$BIN")"
echo "    App: $APP"
[ -n "$DMG" ] && echo "    DMG: $DMG"

# An unsigned build is fine to run locally, but macOS will complain the first
# time. Tell the user up front instead of letting it look broken.
if spctl -a -t exec "$APP" >/dev/null 2>&1; then
  SIGNED=1
else
  SIGNED=0
fi

cat <<EOF

Install it:
  open "$(dirname "$DMG")"
  ...then drag the app into Applications.

Or run it straight from here without installing:
  open "$APP"
EOF

if [ "$SIGNED" = "0" ]; then
  cat <<EOF

Note: this build is not signed with an Apple certificate, so the first launch
will be blocked. Right-click the app and choose Open (double-clicking will not
offer that), or clear the quarantine flag:

  xattr -cr "$APP"

That is only needed for builds you downloaded; a build you compiled yourself on
this Mac is usually not quarantined at all. See docs/MACOS.md to set up signing
so this never affects the people who download your releases.
EOF
fi
