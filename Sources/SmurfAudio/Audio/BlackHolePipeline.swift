import Foundation
import CoreAudio
import AVFoundation
import AppKit

/// Manages detection and routing for the BlackHole virtual audio driver.
///
/// Responsibilities:
/// - Detects if BlackHole is present in the enumerated CoreAudio devices.
/// - Sets BlackHole as the macOS system default output device when routing starts.
/// - Restores the user's physical output device when routing stops or the app terminates.
final class BlackHolePipeline {

    // MARK: - Properties

    private let deviceManager: AudioDeviceManager

    /// The user's original physical output device before BlackHole takeover.
    private(set) var originalOutputDevice: AudioDevice?

    /// The physical device where audio should be heard.
    private(set) var targetOutputDevice: AudioDevice?

    /// Whether audio routing through BlackHole is currently active.
    private(set) var isRoutingActive: Bool = false

    // MARK: - Initialization

    init(deviceManager: AudioDeviceManager) {
        self.deviceManager = deviceManager
        setupTerminationHandlers()
    }

    deinit {
        stopRouting()
    }

    // MARK: - BlackHole Detection

    /// Returns the first available BlackHole output device, if installed.
    var blackHoleDevice: AudioDevice? {
        deviceManager.outputDevices.first { $0.isBlackHole }
    }

    /// Whether BlackHole is available in the current audio device list.
    var isBlackHoleAvailable: Bool {
        blackHoleDevice != nil
    }

    // MARK: - Routing Control

    /// Activates system routing through BlackHole.
    ///
    /// - Parameter targetPhysical: The physical device where audio will eventually be routed.
    /// - Throws: An error if BlackHole is not installed or device switching fails.
    func startRouting(targetPhysical: AudioDevice) throws {
        guard let blackHole = blackHoleDevice else {
            throw CoreAudioError.invalidDevice
        }

        // Save current default output if not already routing
        if !isRoutingActive {
            originalOutputDevice = deviceManager.defaultOutputDevice
        }

        targetOutputDevice = targetPhysical

        // Redirect macOS system output to BlackHole
        try deviceManager.setDefaultOutputDevice(blackHole)
        isRoutingActive = true
    }

    /// Stops BlackHole routing and restores the system default output device.
    func stopRouting() {
        guard isRoutingActive else { return }

        // Restore to original device or target device
        if let restoreDevice = originalOutputDevice ?? targetOutputDevice {
            try? deviceManager.setDefaultOutputDevice(restoreDevice)
        }

        isRoutingActive = false
    }

    /// Updates the physical destination device without interrupting BlackHole capture.
    func updateTargetDevice(_ newTarget: AudioDevice) {
        targetOutputDevice = newTarget
    }

    // MARK: - Safety & Crash Restoration

    private func setupTerminationHandlers() {
        // Handle normal app quit
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopRouting()
        }

        // Handle Unix termination signals (SIGINT, SIGTERM)
        let restoreHandler: @convention(c) (Int32) -> Void = { _ in
            // Restore default audio synchronously before process exit
            if let savedID = BlackHolePipeline.savedDefaultDeviceID {
                var deviceID = savedID
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                AudioObjectSetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &address,
                    0,
                    nil,
                    UInt32(MemoryLayout<AudioDeviceID>.size),
                    &deviceID
                )
            }
            exit(0)
        }

        signal(SIGINT, restoreHandler)
        signal(SIGTERM, restoreHandler)
    }

    // Shared static storage for signal handlers
    static var savedDefaultDeviceID: AudioDeviceID?
}
