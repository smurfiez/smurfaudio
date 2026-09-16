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
    @Published var isBoostActive: Bool = false {
        didSet {
            limiter.isBoostActive = isBoostActive
        }
    }

    /// Boost overdrive gain amount (e.g. 6.0 dB or 12.0 dB)
    @Published var boostGain: Float = 6.0 {
        didSet {
            limiter.boostGain = boostGain
        }
    }

    /// Whether this application is pinned to the user's favorites
    @Published var isFavorite: Bool = false

    // MARK: - Audio & Capture Internals

    /// Dedicated AVAudioPlayerNode routed into the audio engine mixer.
    let playerNode = AVAudioPlayerNode()

    /// Synchronizes audio buffer scheduling with audio engine node attachment/detachment.
    let nodeLock = NSRecursiveLock()

    /// Dedicated per-app 10-band equalizer unit
    let eq = AudioUnitHosting()

    /// Dedicated per-app Peak Limiter for overdrive boost protection
    let limiter = PeakLimiterHosting()

    /// Real-time audio level meter
    let meter = AudioLevelMeter()

    /// Current live audio level (0.0 to 1.0) for LevelMeterPill
    @Published var meterLevel: Float = 0.0

    /// Stereo pan: -1.0 (full left) to +1.0 (full right), 0.0 = center
    @Published var pan: Float = 0.0

    /// Downmix to mono toggle
    @Published var isMono: Bool = false

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

    // MARK: - Profile Serialization

    func makeProfile(targetDeviceUID: String?) -> AppAudioProfile {
        AppAudioProfile(
            volume: volume,
            isMuted: isMuted,
            isBoostActive: isBoostActive,
            boostGain: limiter.boostGain,
            pan: pan,
            isMono: isMono,
            targetDeviceUID: targetDeviceUID,
            eqPreset: eq.selectedPreset.rawValue,
            eqBandGains: eq.bands.map { $0.gain },
            isEQBypassed: eq.isBypassed
        )
    }

    func applyProfile(_ profile: AppAudioProfile) {
        self.volume = profile.volume
        self.isMuted = profile.isMuted
        self.isBoostActive = profile.isBoostActive
        self.limiter.boostGain = profile.boostGain
        self.limiter.isBoostActive = profile.isBoostActive
        self.pan = profile.pan
        self.isMono = profile.isMono
        if let presetName = profile.eqPreset, let preset = EQPreset(rawValue: presetName) {
            self.eq.selectedPreset = preset
        }
        if let gains = profile.eqBandGains {
            for (index, gain) in gains.enumerated() {
                self.eq.setGain(forBand: index, gain: gain)
            }
        }
        self.eq.isBypassed = profile.isEQBypassed
    }
}
