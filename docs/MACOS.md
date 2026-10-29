# macOS: building, distributing, and the App Store

Two different macOS builds come out of this repository, and they are not
interchangeable:

| | Direct download (`.dmg`) | Mac App Store (`.pkg`) |
|---|---|---|
| Config | `src-tauri/tauri.macos.conf.json` | `src-tauri/tauri.appstore.conf.json` |
| Cargo features | default (`tauri-mode`, `self-updater`) | `appstore-mode` (no updater) |
| Entitlements | `entitlements.plist` (Hardened Runtime) | `entitlements.appstore.plist` (App Sandbox) |
| Capability file | `capabilities/default.json` | `capabilities/appstore.json` |
| In-app updates | yes | no — Apple forbids them |
| Transparent title bar | yes (`macOSPrivateApi`) | no — private APIs are rejected |
| Built by | `.github/workflows/release.yml` on a tag | `scripts/build-macos-appstore.sh` on your Mac |
| Apple account needed | only to avoid the Gatekeeper warning | yes, mandatory |

The short version: **the `.dmg` is the one that gets everybody running the
app**, and CI produces it with no Apple account at all. The App Store is a
separate, slower track with a licensing problem to resolve first — see
[Mac App Store](#mac-app-store) below.

---

## 1. Getting the `.dmg`

### On your own Mac — the quickest path

One command. It checks the prerequisites, explains exactly what is missing if
something is, and prints where the `.dmg` ended up:

```bash
bash scripts/build-macos.sh
```

Add `--native` to build only for the Mac you are sitting at, which is
noticeably faster than a universal build:

```bash
bash scripts/build-macos.sh --native
```

You need Xcode command line tools (`xcode-select --install`), Node 18+ and
Rust. The first build compiles the whole Rust core and takes a while; later
builds reuse the cache.

The equivalent manual steps, if you prefer them:

```bash
npm ci
rustup target add aarch64-apple-darwin x86_64-apple-darwin
npm run tauri:build:macos:universal
```

The `.dmg` lands in
`src-tauri/target/universal-apple-darwin/release/bundle/dmg/`.

### From CI, without a Mac

> **Check Actions is enabled first.** GitHub disables Actions by default on
> forked repositories, and this repository is a fork — so no workflow here has
> ever run. Turn it on under *Settings → Actions → General*, or with the
> "I understand my workflows, go ahead and enable them" button on the Actions
> tab. Until then neither of the workflows below can produce anything.

Two separate workflows, deliberately:

- **`build-macos.yml`** — builds a universal `.dmg` and uploads it as a
  downloadable artifact, and **publishes nothing**. Runs on `workflow_dispatch`
  (Actions tab → *Build macOS app* → *Run workflow*), and automatically on
  pushes and pull requests that touch `src/`, `src-tauri/` or the manifests.
  This is how you get a Mac build on demand, and it is what catches
  macOS-only compile failures — Metal, `wgpu`, the `objc` crates — that a Linux
  or Windows job cannot surface. It verifies the bundle really contains both
  the `arm64` and `x86_64` slices, and reports the Gatekeeper verdict in the
  run summary.
- **`release.yml`** — runs on a version tag and publishes to the Releases page,
  macOS included:

```bash
git tag v2.0.1 && git push origin v2.0.1
```

Both build for `universal-apple-darwin`, so one `.dmg` runs natively on both
Apple Silicon and Intel. There is no longer a separate `x64` download.

---

## 2. Signing and notarization

An unsigned build **works**, but the first launch is ugly: macOS says the app
"cannot be opened because the developer cannot be verified", or "is damaged and
should be moved to the Bin" if it was downloaded through a browser. Users then
have to right-click the app and choose **Open**, or clear the quarantine flag:

```bash
xattr -cr "/Applications/Satisfactory Layout Tool.app"
```

That is a real drop-off point for a tool you want "everyone" to install, and
the only way to remove it is an Apple Developer Program membership
(99 USD/year). Signing is wired into the release workflow already and switches
on as soon as the secrets exist — no workflow edits needed.

### What you need

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. In the developer portal create a **Developer ID Application** certificate —
   this is the one for apps distributed outside the App Store. Install it, then
   export it from Keychain Access as a `.p12` with a password.
3. Create an **app-specific password** for your Apple ID at
   [appleid.apple.com](https://appleid.apple.com) under *Sign-In and Security*.
   Your normal Apple ID password will not work for notarization.

### The repository secrets

Add these under *Settings → Secrets and variables → Actions*:

| Secret | Value |
|---|---|
| `APPLE_CERTIFICATE` | the `.p12`, base64-encoded: `base64 -i cert.p12 \| pbcopy` |
| `APPLE_CERTIFICATE_PASSWORD` | the password you set when exporting the `.p12` |
| `APPLE_SIGNING_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `KEYCHAIN_PASSWORD` | any random string; CI uses it for a temporary keychain |
| `APPLE_ID` | the Apple ID email on the developer account |
| `APPLE_PASSWORD` | the app-specific password from step 3 |
| `APPLE_TEAM_ID` | your 10-character Team ID from the developer portal |

Run `security find-identity -v -p codesigning` on your Mac to get the exact
`APPLE_SIGNING_IDENTITY` string, quotes and parentheses included.

With all seven set, the workflow signs the app, submits it to Apple's notary
service, staples the ticket, and the `.dmg` opens on a double-click. With none
of them set the job still succeeds and produces a working unsigned `.dmg`; it
logs a warning saying so, and the `Report signing status` step prints the
`codesign`/`spctl` verdict either way, so you can confirm from the job log
which kind of build you got.

> Partial credentials are the one bad state: a certificate without
> notarization credentials produces a signed-but-not-notarized app, which
> Gatekeeper still blocks. Set all seven or none.

---

## 3. In-app updates

`latest.json`, generated by the `publish-release` job, drives the updater. The
macOS entry points `darwin-universal`, `darwin-aarch64` and `darwin-x86_64` at
the same universal `.app.tar.gz` so the lookup resolves whichever target string
an installed build reports.

Updater signing is separate from Apple signing and is already configured
through `TAURI_SIGNING_PRIVATE_KEY`. If the `.app.tar.gz` or its `.sig` is
missing, the release job prints a warning and omits the macOS entry rather than
publishing a manifest that would break update checks.

---

## 4. Mac App Store

### Read this first: the licensing conflict

This project is **AGPL-3.0-or-later**, and that is genuinely incompatible with
the App Store's terms. Apple imposes usage restrictions and DRM on everything
it distributes, while the (A)GPL forbids adding restrictions on top of the
rights it grants. This is not a theoretical worry — it is why VLC was pulled
from the App Store.

You are the sole copyright holder (see `NOTICE`), so **you can fix this, but it
has to be a deliberate decision**, not something a build script can do for you.
The usual options:

- **Add a licensing exception.** Keep AGPL-3.0 and append a clause granting
  permission to distribute through app stores with their additional
  restrictions. This is the normal route for a single-copyright-holder project.
- **Dual-license.** Keep AGPL-3.0 for the public repository and ship the App
  Store build under a separate proprietary licence that you grant yourself.
- **Skip the App Store.** A notarized `.dmg` installs in one double-click, so
  the store buys you discoverability rather than reach.

Third-party dependencies are not a blocker here: the Rust crates and npm
packages in use are permissively licensed (MIT/Apache-2.0). The conflict is
purely between your own AGPL terms and Apple's.

Decide this before spending money on a membership.

### Other things Apple will hold you to

- **Sandboxing is mandatory.** `entitlements.appstore.plist` enables the App
  Sandbox. Note that it deliberately omits
  `com.apple.security.cs.disable-library-validation` and
  `com.apple.security.cs.allow-unsigned-executable-memory`, which are present
  in the direct-download entitlements and are rejected in sandboxed
  submissions.
- **The app runs a local HTTP server** on `127.0.0.1:5175`. This is allowed —
  `com.apple.security.network.server` covers it — but expect a reviewer
  question about why a layout planner needs a server. The honest answer is that
  the Rust core and the web view talk over loopback, and nothing leaves the
  machine.
- **No self-updating.** `appstore-mode` compiles `tauri-plugin-updater` out
  entirely, which is why there is a second capability file: build-time
  permission resolution would otherwise fail on `updater:default`.
- **No private APIs.** The transparent/overlay title bar on the direct build
  uses `macOSPrivateApi`, which is an automatic rejection. The App Store config
  turns it off, so **the App Store build has a normal title bar** and looks
  slightly different from the `.dmg`. Check that the UI still looks right.
- **The bundle identifier must match your registered App ID.**
  `tauri.appstore.conf.json` currently says
  `com.handleconsolidated.satisfactory-layout-tool`. Change it to whatever you
  register, and note that it differs from the direct build's
  `com.satisfactory-layout-tool` on purpose — the two installs therefore keep
  separate application data.

### Building and submitting

You need a Mac with Xcode command line tools; this cannot be done from CI on a
generic runner, and it cannot be done from Linux or Windows at all.

1. In the developer portal create **3rd Party Mac Developer Application** and
   **3rd Party Mac Developer Installer** certificates. These are App
   Store-specific and are *not* the same as the Developer ID certificate used
   for the `.dmg`.
2. Register the App ID, then create the app record in
   [App Store Connect](https://appstoreconnect.apple.com).
3. Build and package:

```bash
export APPLE_SIGNING_IDENTITY="3rd Party Mac Developer Application: Your Name (TEAMID)"
export APPLE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)"
npm run macos:appstore
```

   The script checks the certificates are actually in your keychain before
   starting, verifies after signing that the sandbox entitlement really made it
   into the binary, and writes
   `dist-appstore/SatisfactoryLayoutTool-<version>-appstore.pkg`.

4. Upload the `.pkg` with Apple's
   [Transporter](https://apps.apple.com/app/transporter/id1450874784) app, or
   re-run the script with `UPLOAD=1` and either `APPLE_API_KEY` +
   `APPLE_API_ISSUER` or `APPLE_ID` + `APPLE_PASSWORD`.
5. Attach the processed build to a version in App Store Connect and submit for
   review.

Bump `version` in `package.json`, `src-tauri/Cargo.toml` and the three Tauri
configs together; Apple rejects a build whose version is not higher than the
last one you uploaded.

---

## 5. Troubleshooting

**"is damaged and should be moved to the Bin"** — the build is unsigned and the
browser set a quarantine flag. Right-click → **Open**, or run
`xattr -cr "/Applications/Satisfactory Layout Tool.app"`. Fix it properly by
setting the signing secrets in [section 2](#2-signing-and-notarization).

**The CI job fails on `macos-private-api`** — `tauri.macos.conf.json` sets
`macOSPrivateApi: true`, which requires a matching Cargo feature. The Tauri CLI
adds that feature from the config automatically, so build through
`npm run tauri:build:macos*` or `tauri-action`. A bare `cargo build` will fail
this check, and adding the feature to `Cargo.toml` by hand breaks the App Store
build instead, because the check runs in both directions.

**`Permission updater:default not found`** — you are building `appstore-mode`
but `build.rs` picked the wrong capability file. `build.rs` chooses between
`capabilities/default.json` and `capabilities/appstore.json` on the
`self-updater` feature. Note that `app.security.capabilities` in the Tauri
config cannot substitute for this: it filters capabilities at runtime, but
every file in `capabilities/` is still parsed and validated at build time.

**The app window has no title bar on the `.dmg` build** — that is intended
(`titleBarStyle: Overlay` plus `hiddenTitle`). The App Store build uses a
standard title bar because the private API that enables the overlay is not
allowed there.
