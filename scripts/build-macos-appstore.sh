#!/usr/bin/env bash
#
# Builds the Mac App Store variant and wraps it in a signed .pkg that can be
# uploaded to App Store Connect.
#
# This cannot run in CI on a generic runner and cannot run on Linux or Windows:
# it needs macOS, Xcode command line tools, and your Apple certificates in the
# login keychain. See docs/MACOS.md for the full walkthrough, including how to
# obtain the certificates and what to do in App Store Connect afterwards.
#
# Required environment:
#   APPLE_SIGNING_IDENTITY    "3rd Party Mac Developer Application: NAME (TEAMID)"
#   APPLE_INSTALLER_IDENTITY  "3rd Party Mac Developer Installer: NAME (TEAMID)"
#
# Optional environment:
#   APPLE_API_ISSUER / APPLE_API_KEY   App Store Connect API key, to upload
#   APPLE_ID / APPLE_PASSWORD          Apple ID + app-specific password, to upload
#   UPLOAD=1                           Attempt the upload after building
#
set -euo pipefail

cd "$(dirname "$0")/.."

die() { printf '\nerror: %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "The Mac App Store build requires macOS. On other systems you can
       only build the .dmg via CI (.github/workflows/release.yml)."

command -v xcrun >/dev/null || die "Xcode command line tools not found. Run: xcode-select --install"
command -v productbuild >/dev/null || die "productbuild not found; install the Xcode command line tools."

: "${APPLE_SIGNING_IDENTITY:?Set APPLE_SIGNING_IDENTITY to your '3rd Party Mac Developer Application' identity. See docs/MACOS.md}"
: "${APPLE_INSTALLER_IDENTITY:?Set APPLE_INSTALLER_IDENTITY to your '3rd Party Mac Developer Installer' identity. See docs/MACOS.md}"

# Fail early rather than after a 20 minute build if the certs are not actually
# in the keychain.
security find-identity -v -p codesigning | grep -qF "$APPLE_SIGNING_IDENTITY" \
  || die "Signing identity not found in the keychain:
         $APPLE_SIGNING_IDENTITY
       Run 'security find-identity -v -p codesigning' to see what is available."

echo "==> Adding Rust targets for the universal build"
rustup target add aarch64-apple-darwin x86_64-apple-darwin

echo "==> Building the App Store variant (sandboxed, no self-updater)"
# tauri:build:appstore pins --no-default-features --features appstore-mode, so
# tauri-plugin-updater is left out of the binary entirely; Apple rejects apps
# that update themselves outside the store.
APPLE_SIGNING_IDENTITY="$APPLE_SIGNING_IDENTITY" npm run tauri:build:appstore

BUNDLE_DIR="src-tauri/target/universal-apple-darwin/release/bundle/macos"
APP=$(find "$BUNDLE_DIR" -maxdepth 1 -name '*.app' | head -1)
[ -n "$APP" ] || die "No .app bundle produced under $BUNDLE_DIR"
echo "==> Built: $APP"

echo "==> Verifying the sandbox entitlement actually made it into the binary"
ENTS=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | tr -d '\0' || true)
case "$ENTS" in
  *com.apple.security.app-sandbox*)
    echo "    app-sandbox present" ;;
  *)
    die "The App Sandbox entitlement is missing from the signed bundle. App Store
       review rejects unsandboxed apps. Check that src-tauri/entitlements.appstore.plist
       was applied and that APPLE_SIGNING_IDENTITY is a '3rd Party Mac Developer
       Application' certificate." ;;
esac

# A private-API build is rejected, and macOSPrivateApi is deliberately false in
# tauri.appstore.conf.json. Catch a regression here rather than at review.
if codesign -dv --verbose=4 "$APP" 2>&1 | grep -qi 'adhoc'; then
  die "The bundle is ad-hoc signed, not signed with your Apple certificate."
fi

VERSION=$(node -p "require('./package.json').version")
OUT="dist-appstore"
mkdir -p "$OUT"
PKG="$OUT/SatisfactoryLayoutTool-${VERSION}-appstore.pkg"

echo "==> Wrapping into a signed installer package"
productbuild \
  --component "$APP" /Applications \
  --sign "$APPLE_INSTALLER_IDENTITY" \
  "$PKG"

echo "==> Verifying the package signature"
pkgutil --check-signature "$PKG" | sed 's/^/    /'

echo
echo "Built $PKG"

if [ "${UPLOAD:-0}" = "1" ]; then
  echo "==> Uploading to App Store Connect"
  if [ -n "${APPLE_API_KEY:-}" ] && [ -n "${APPLE_API_ISSUER:-}" ]; then
    xcrun altool --upload-app -f "$PKG" -t macos \
      --apiKey "$APPLE_API_KEY" --apiIssuer "$APPLE_API_ISSUER"
  elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_PASSWORD:-}" ]; then
    xcrun altool --upload-app -f "$PKG" -t macos \
      -u "$APPLE_ID" -p "$APPLE_PASSWORD"
  else
    die "UPLOAD=1 needs either APPLE_API_KEY + APPLE_API_ISSUER, or
       APPLE_ID + APPLE_PASSWORD (an app-specific password)."
  fi
  echo "Uploaded. The build appears in App Store Connect after processing."
else
  cat <<EOF

Next steps:
  1. Upload it, either with Apple's Transporter app, or by re-running this
     script with UPLOAD=1 and the credentials described in docs/MACOS.md.
  2. In App Store Connect, attach the processed build to a version and submit
     it for review.

Read the "Mac App Store" section of docs/MACOS.md before submitting — there is
an AGPL-3.0 licensing conflict you need to resolve first, and it is the one
thing that cannot be fixed by changing the build.
EOF
fi
