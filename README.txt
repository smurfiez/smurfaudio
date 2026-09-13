================================================================================
                                  SmurfAudio
                    Per-Application Audio Routing for macOS
================================================================================

Overview:
SmurfAudio is a native macOS utility that provides granular, per-app audio routing,
equalization, and master volume controls via a menu bar interface and floating window.

--------------------------------------------------------------------------------
1. System Requirements & Prerequisites
--------------------------------------------------------------------------------
- macOS 14.0 (Sonoma) or newer (Apple Silicon / Intel)
- Xcode Command Line Tools or Xcode 15+:
    xcode-select --install
- (Recommended) BlackHole 2ch Virtual Audio Driver:
  Required for system-wide and per-app audio redirection.
  Install via Homebrew:
    brew install blackhole-2ch
- (Optional) Node.js (v18+) for running Cucumber BDD feature tests.

--------------------------------------------------------------------------------
2. Installation & Building
--------------------------------------------------------------------------------

Clone the repository:
    git clone https://github.com/smurfiez/smurfaudio.git
    cd smurfaudio

Build the macOS App Bundle:
    ./build_app.sh

This script will:
  1. Compile the Swift binary using Swift Package Manager.
  2. Assemble the macOS application bundle (SmurfAudio.app).
  3. Sign the application bundle with ScreenCaptureKit and audio input entitlements.

(Optional) Install to Applications:
    cp -R SmurfAudio.app /Applications/

--------------------------------------------------------------------------------
3. How to Run
--------------------------------------------------------------------------------

Option A: Launch via Finder or Terminal:
    open SmurfAudio.app
    # or if installed in /Applications:
    open /Applications/SmurfAudio.app

Option B: Run directly from command line (for development / debugging):
    swift run SmurfAudio

--------------------------------------------------------------------------------
4. Initial Setup & Permissions
--------------------------------------------------------------------------------
Upon first launch, macOS requires permissions for audio capturing and hardware
volume control:

1. System Audio / Microphone Recording:
   - SmurfAudio uses ScreenCaptureKit to capture application-level audio.
   - When prompted, grant Screen Recording / Audio permissions in:
     System Settings -> Privacy & Security -> Screen & System Audio Recording.

2. Accessibility (Optional - for Hardware Media Key Interception):
   - To allow SmurfAudio to intercept keyboard volume keys:
     Click "Enable Volume Keys" in the app footer or configure in:
     System Settings -> Privacy & Security -> Accessibility
     and enable SmurfAudio.

--------------------------------------------------------------------------------
5. Running Tests
--------------------------------------------------------------------------------

Unit & Integration Tests:
    ./run_tests.sh

Cucumber BDD Feature Suite:
    ./run_feature_tests.sh
