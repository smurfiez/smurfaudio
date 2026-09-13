# SmurfAudio

> Per-application audio routing, graphic equalization, and volume mixer for macOS Sonoma and later.

SmurfAudio is a native macOS menu bar application built with Swift and SwiftUI. It enables individual application audio capture, per-app output routing (via BlackHole virtual audio loopbacks), a 10-band graphic equalizer with presets, and hardware media key interception.

---

## Features

- **Per-App Audio Routing**: Direct sound from specific applications (e.g. Music, Safari, Chrome) to any connected physical or virtual output device.
- **10-Band Graphic Equalizer**: Built-in Apple `kAudioUnitSubType_GraphicEQ` processing with presets (*Bass Boost*, *Treble Boost*, *Vocal*, *Electronic*, etc.) and manual band gain tuning (-12 dB to +12 dB).
- **Master & Individual Controls**: Real-time volume sliders and mute toggles for system master input/output as well as individual apps.
- **Hardware Media Key Interception**: Intercepts macOS keyboard volume/mute keys (F10, F11, F12) via a CoreGraphics event tap to adjust mixer volume directly.
- **Menu Bar & Detached Window**: Lives discreetly in the macOS menu bar with an option to tear off into a floating utility window.

---

## Prerequisites

- **macOS**: 14.0 (Sonoma) or newer (Apple Silicon & Intel)
- **Xcode Command Line Tools** (Swift 5.9+):
  ```bash
  xcode-select --install
  ```
- **BlackHole 2ch Driver** *(Recommended for virtual audio redirection)*:
  ```bash
  brew install blackhole-2ch
  ```
- **Node.js** (v18+) *(Optional, for Cucumber BDD feature test runner)*

---

## Building & Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/smurfiez/smurfaudio.git
   cd smurfaudio
   ```

2. **One-Click Automated Install (App + BlackHole Driver):**
   ```bash
   ./install.sh
   ```
   This script builds `SmurfAudio.app`, verifies and installs the BlackHole 2ch audio loopback driver into `/Library/Audio/Plug-Ins/HAL/`, reloads `coreaudiod`, and installs the application to `/Applications`.

3. **Build Installer Package (.pkg) with Prerequisites:**
   ```bash
   ./create_installer.sh
   ```
   This produces `SmurfAudioInstaller.pkg`, a standalone macOS installer that installs both `SmurfAudio.app` and `BlackHole2ch.driver` in one step via standard macOS GUI installation.

4. **Package into Distributable DMG:**
   ```bash
   ./create_dmg.sh
   ```
   This generates `SmurfAudio.dmg` containing the 1-click installer package (`Install SmurfAudio.pkg`), the standalone app bundle (`SmurfAudio.app`), and an `/Applications` drag-and-drop link.

5. **Manual Build Only:**
   ```bash
   ./build_app.sh
   cp -R SmurfAudio.app /Applications/
   ```

---

## How to Run

### Launch Application Bundle
```bash
open SmurfAudio.app
# or if moved to Applications:
open /Applications/SmurfAudio.app
```

### Run Directly from Source (Development)
```bash
swift run SmurfAudio
```

---

## Required Permissions

Upon initial launch, macOS prompts for necessary permissions:

1. **Screen & System Audio Recording (ScreenCaptureKit)**:
   - Required to capture audio streams directly from individual running processes.
   - Grant permission in **System Settings** → **Privacy & Security** → **Screen & System Audio Recording**.
2. **Accessibility** *(Optional)*:
   - Required to intercept hardware keyboard volume keys (F10/F11/F12).
   - Click **"Enable Volume Keys"** in the app footer or configure in **System Settings** → **Privacy & Security** → **Accessibility**.

---

## Running Tests

### Unit & Integration Tests (Swift Testing)
```bash
./run_tests.sh
```

### Cucumber BDD Feature Suite
```bash
./run_feature_tests.sh
```

---

## Project Structure

```
smurfaudio/
├── Info.plist                  # Application metadata and permission descriptions
├── Package.swift               # Swift Package Manager manifest
├── SmurfAudio.entitlements     # Entitlements for ScreenCaptureKit and Audio
├── build_app.sh                # App bundle builder and code-signer
├── run_tests.sh                # Swift Testing suite runner
├── run_feature_tests.sh        # Cucumber BDD runner via automation-mcp
├── Sources/
│   └── SmurfAudio/
│       ├── App/                # App entry point and NSApplicationDelegate
│       ├── Audio/              # CoreAudio HAL, BlackHole loopback, AudioUnit EQ
│       ├── Input/              # Media key event tap interceptor
│       ├── Models/             # AudioDevice, AudioState, AppAudioSource
│       ├── Utilities/          # CoreAudio helpers and property listeners
│       └── Views/              # SwiftUI Popover, EQ, and device rows
├── Tests/
│   └── SmurfAudioTests/        # Swift Testing unit test cases
└── features/                   # Gherkin BDD specs and TypeScript steps
```

---

## License

MIT License. See repository details for full license text.
