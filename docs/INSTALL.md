# Installation Guide

This guide covers how to install and run the Satisfactory Layout Tool on Windows, macOS, and Linux.

## System Requirements

### Minimum Requirements
- **CPU**: 64-bit processor (x86_64 or ARM64)
- **RAM**: 4 GB
- **Storage**: 200 MB available space
- **Display**: 1200x800 minimum resolution

### Recommended Requirements
- **CPU**: Modern multi-core processor
- **RAM**: 8 GB or more
- **GPU**: Hardware acceleration supported
- **Display**: 1920x1080 or higher

### Operating System Requirements

| Platform | Minimum Version |
|----------|-----------------|
| Windows  | Windows 10 version 1803 (April 2018 Update) or later |
| macOS    | macOS 12 (Monterey) or later |
| Linux    | Ubuntu 22.04 LTS or equivalent |

---

## Windows Installation

### Download
Download the latest Windows installer from the [Releases page](https://github.com/HandleConsolidated/nexus-satisfactory-layout-tool/releases):
- **MSI Installer**: `Satisfactory_Layout_Tool_x.x.x_x64_en-US.msi` (recommended)
- **NSIS Installer**: `Satisfactory_Layout_Tool_x.x.x_x64-setup.exe`

### Installation Steps
1. Download the installer
2. Double-click to run
3. If you see a Windows SmartScreen warning:
   - Click **"More info"**
   - Click **"Run anyway"**
4. Follow the installation wizard
5. Launch from Start Menu or Desktop shortcut

### WebView2 Runtime
The application requires Microsoft Edge WebView2 Runtime. This is pre-installed on:
- Windows 11
- Windows 10 (version 1803 and later, with recent updates)

If not installed, the installer will download it automatically.

### Uninstallation
- Go to **Settings > Apps > Installed Apps**
- Find "Satisfactory Layout Tool"
- Click **Uninstall**

---

## macOS Installation

### Download
Download the latest macOS installer from the [Releases page](https://github.com/HandleConsolidated/nexus-satisfactory-layout-tool/releases):
- **DMG**: `Satisfactory_Layout_Tool_x.x.x_universal.dmg`

One download covers both Apple Silicon (M1/M2/M3/M4) and Intel Macs — it is a
universal binary, so there is no architecture to choose.

### Installation Steps
1. Download the DMG
2. Open the DMG file
3. Drag the app to the Applications folder
4. Eject the DMG

### First Launch (Gatekeeper)
Unless the release was signed with an Apple Developer certificate, macOS
Gatekeeper blocks the first launch — it may say the developer "cannot be
verified", or that the app "is damaged and should be moved to the Bin". The app
is fine; macOS flags everything downloaded from outside the App Store that
isn't notarized.

The quickest way through:

1. **Right-click** (or Control-click) the app in Applications and choose
   **Open**, then confirm. Double-clicking will not offer this option.

If that doesn't appear, use System Settings instead:

1. Try to open the app normally
2. Go to **System Settings > Privacy & Security**
3. Scroll down to find the blocked app message
4. Click **"Open Anyway"**
5. Confirm in the dialog

**Alternative method** (Terminal):
```bash
xattr -cr /Applications/Satisfactory\ Layout\ Tool.app
```

You only need to do this once. Maintainers: see
[docs/MACOS.md](MACOS.md) for how to sign and notarize releases so this step
disappears for users.

### Uninstallation
- Drag the app from Applications to Trash
- Empty Trash

---

## Linux Installation

### Download Options
Download from the [Releases page](https://github.com/HandleConsolidated/nexus-satisfactory-layout-tool/releases):

| Format | File | Best For |
|--------|------|----------|
| AppImage | `Satisfactory_Layout_Tool_x.x.x_amd64.AppImage` | Universal, no installation |
| Debian | `satisfactory-layout-tool_x.x.x_amd64.deb` | Ubuntu, Debian, Pop!_OS |
| RPM | `satisfactory-layout-tool-x.x.x-1.x86_64.rpm` | Fedora, RHEL, openSUSE |

### AppImage Installation (Recommended)
```bash
chmod +x Satisfactory_Layout_Tool_x.x.x_amd64.AppImage
./Satisfactory_Layout_Tool_x.x.x_amd64.AppImage
```

### Debian/Ubuntu Installation
```bash
sudo dpkg -i satisfactory-layout-tool_x.x.x_amd64.deb
sudo apt-get install -f      # fix any missing deps
satisfactory-layout-tool
```

### Fedora/RPM Installation
```bash
sudo dnf install satisfactory-layout-tool-x.x.x-1.x86_64.rpm
satisfactory-layout-tool
```

### Dependencies
The application requires these libraries (included in `.deb` / `.rpm` dependencies):
- `libwebkit2gtk-4.1-0` (or `webkit2gtk3`)
- `libgtk-3-0` (or `gtk3`)

---

## Portable Build (Windows)

If you don't want an installer, you can use the portable build:

1. Download `SatisfactoryLayoutTool-x.x.x-windows.zip` from Releases
2. Extract the zip anywhere
3. Double-click `SatisfactoryLayoutTool.exe`
4. The app opens in your default browser

The portable build runs in your browser instead of using a native window. No installation required.

---

## Verifying Your Installation

### Check the Version
1. Launch the application
2. The version number appears in the window title and the **Help → About** menu

### Verify Checksums
Each release includes SHA256 checksums. To verify:

**Windows (PowerShell)**:
```powershell
Get-FileHash -Algorithm SHA256 Satisfactory_Layout_Tool_x.x.x_x64-setup.exe
```

**macOS/Linux**:
```bash
sha256sum Satisfactory_Layout_Tool_x.x.x_amd64.AppImage
```

---

## Troubleshooting

### Windows: "Windows protected your PC" message
This appears because the app is not yet code-signed by a trusted CA.
1. Click "More info"
2. Click "Run anyway"

### macOS: "Cannot be opened because the developer cannot be verified"
1. Go to System Settings > Privacy & Security
2. Click "Open Anyway" next to the blocked app
3. Or run: `xattr -cr /Applications/Satisfactory\ Layout\ Tool.app`

### Linux: Application won't start
Check for missing dependencies:
```bash
# Ubuntu/Debian
sudo apt-get install libwebkit2gtk-4.1-0 libgtk-3-0

# Fedora
sudo dnf install webkit2gtk3 gtk3
```

### Performance Issues
- Ensure hardware acceleration is enabled in your system
- Close other GPU-intensive applications
- For very large layouts (500+ buildings), some slowdown is expected

### Getting Help
- [Report a Bug](https://github.com/HandleConsolidated/nexus-satisfactory-layout-tool/issues/new?template=bug_report.md)
- [Request a Feature](https://github.com/HandleConsolidated/nexus-satisfactory-layout-tool/issues/new?template=feature_request.md)

---

## Building from Source

For developers who want to build from source, see [docs/BUILD.md](docs/BUILD.md).

```bash
git clone https://github.com/HandleConsolidated/nexus-satisfactory-layout-tool.git
cd nexus-satisfactory-layout-tool
npm install
npm run dev
```

See [docs/BUILD.md](docs/BUILD.md) for production build commands and release procedures.
