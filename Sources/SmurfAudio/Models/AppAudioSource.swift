import Foundation
import AppKit
import AVFoundation
import ScreenCaptureKit

/// Represents an application whose audio can be isolated and controlled.
final class AppAudioSource: ObservableObject, Identifiable {

    // MARK: - Identity

    let id = UUID()
    let processID: pid_t
    let bundleIdentifier: String
    let name: String

    // MARK: - State

    @Published var volume: Float = 1.0 {
        didSet {
            playerNode.volume = isMuted ? 0.0 : volume
        }
    }

    @Published var isMuted: Bool = false {
        didSet {
            playerNode.volume = isMuted ? 0.0 : volume
        }
    }

    @Published var isCapturing: Bool = false
    @Published var captureError: String?

    /// Specific output destination device. If nil, uses default output.
    @Published var selectedOutputDeviceID: AudioDeviceID?

    /// Whether overdrive boost is engaged (+6 dB gain boost)
    @Published var isBoostActive: Bool = false

    /// Whether this application is pinned to the user's favorites
    @Published var isFavorite: Bool = false

    // MARK: - Audio & Capture Internals

    /// Dedicated AVAudioPlayerNode routed into the audio engine mixer.
    let playerNode = AVAudioPlayerNode()

    /// Synchronizes audio buffer scheduling with audio engine node attachment/detachment.
    let nodeLock = NSRecursiveLock()

    /// Dedicated per-app 10-band equalizer unit
    let eq = AudioUnitHosting()

    /// The ScreenCaptureKit representation of this application.
    var scApp: SCRunningApplication?

    /// Active ScreenCaptureKit stream instance.
    var stream: SCStream?

    // MARK: - App Icon

    lazy var icon: NSImage? = {
        if let app = NSRunningApplication(processIdentifier: processID),
           let icon = app.icon {
            return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }()

    // MARK: - Initialization

    init(processID: pid_t, bundleIdentifier: String, name: String, scApp: SCRunningApplication? = nil) {
        self.processID = processID
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.scApp = scApp
        self.playerNode.volume = volume
    }
}
