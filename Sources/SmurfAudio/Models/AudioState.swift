import Foundation
import AppKit
import CoreAudio
import Combine
import SwiftUI

/// Central observable state for the entire audio system.
///
/// Coordinates ``AudioDeviceManager``, ``BlackHolePipeline``, ``AudioEngineController``,
/// ``AppAudioCaptureManager``, and ``MediaKeyInterceptor``.
final class AudioState: ObservableObject {

    // MARK: Core Audio Controllers

    let deviceManager = AudioDeviceManager()
    let engineController = AudioEngineController()
    lazy var pipeline = BlackHolePipeline(deviceManager: deviceManager)
    let captureManager = AppAudioCaptureManager()
    let mediaKeyInterceptor = MediaKeyInterceptor()
    let permissionManager = PermissionManager()
    let profileStore = AppAudioProfileStore()
    let updateManager = UpdateManager()

    // MARK: Equalizer Reference

    var eq: AudioUnitHosting {
        engineController.eqHosting
    }

    @Published var isShowingEQ: Bool = false

    // MARK: Devices (live from CoreAudio)

    @Published var outputDevices: [AudioDevice] = []
    @Published var inputDevices: [AudioDevice] = []
    @Published var defaultOutputDevice: AudioDevice?
    @Published var defaultInputDevice: AudioDevice?
    @Published var defaultSystemOutputDevice: AudioDevice?

    // MARK: BlackHole & Global Routing

    @Published var isBlackHoleInstalled: Bool = false
    @Published var isRoutingActive: Bool = false
    @Published var routingError: String?

    /// The physical destination device when routing through BlackHole.
    @Published var targetOutputDevice: AudioDevice?

    // MARK: Live Real-Time Meter Levels

    @Published var masterMeterLevel: Float = 0.0

    // MARK: Volume & Boost State

    @Published var systemOutputVolume: Float = 0.75 {
        didSet {
            let effective = isMasterMuted ? 0.0 : systemOutputVolume
            engineController.setVolume(effective)

            // Directly control the physical device hardware volume
            if let target = targetOutputDevice ?? defaultOutputDevice {
                deviceManager.setVolume(for: target.audioDeviceID, volume: effective)
            }
        }
    }
    @Published var isMasterMuted: Bool = false {
        didSet {
            let effective = isMasterMuted ? 0.0 : systemOutputVolume
            engineController.setVolume(effective)

            if let target = targetOutputDevice ?? defaultOutputDevice {
                deviceManager.setVolume(for: target.audioDeviceID, volume: effective)
            }
        }
    }
    @Published var isMasterBoostActive: Bool = false {
        didSet {
            engineController.masterLimiter.isBoostActive = isMasterBoostActive
        }
    }
    @Published var masterBoostGain: Float = 6.0 {
        didSet {
            engineController.masterLimiter.boostGain = masterBoostGain
        }
    }

    @Published var systemInputVolume: Float = 0.50 {
        didSet {
            let effective = isInputMuted ? 0.0 : systemInputVolume
            if let input = defaultInputDevice {
                deviceManager.setVolume(for: input.audioDeviceID, volume: effective, isInput: true)
            }
        }
    }
    @Published var isInputMuted: Bool = false {
        didSet {
            let effective = isInputMuted ? 0.0 : systemInputVolume
            if let input = defaultInputDevice {
                deviceManager.setVolume(for: input.audioDeviceID, volume: effective, isInput: true)
            }
        }
    }
    @Published var isInputBoostActive: Bool = false

    @Published var soundEffectsVolume: Float = 0.25 {
        didSet {
            if let sfx = defaultSystemOutputDevice ?? defaultOutputDevice {
                deviceManager.setVolume(for: sfx.audioDeviceID, volume: isSoundEffectsMuted ? 0.0 : soundEffectsVolume)
            }
        }
    }
    @Published var isSoundEffectsMuted: Bool = false {
        didSet {
            if let sfx = defaultSystemOutputDevice ?? defaultOutputDevice {
                deviceManager.setVolume(for: sfx.audioDeviceID, volume: isSoundEffectsMuted ? 0.0 : soundEffectsVolume)
            }
        }
    }
    @Published var isSoundEffectsBoostActive: Bool = false

    // MARK: UI Layout State

    /// Which row has its inline FX drawer expanded (e.g., "output", "input", "sfx", or an app's UUID string)
    @Published var expandedFXID: String? = nil

    /// Whether the window is pinned to stay floating on screen
    @Published var isWindowPinned: Bool = false

    /// Bundle IDs of apps pinned to favorites
    @Published var favoriteBundleIDs: Set<String> = []

    // MARK: Running Applications (Live ScreenCaptureKit sources)

    @Published var runningApps: [AppAudioSource] = []
    @Published var isScanningApps: Bool = false

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private var wasAutoRoutedForSecondaryOutput: Bool = false

    // MARK: Init

    init() {
        // Forward device manager state changes
        deviceManager.$outputDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self else { return }
                self.outputDevices = devices
                self.isBlackHoleInstalled = devices.contains { $0.isBlackHole }
                if self.targetOutputDevice == nil {
                    // Pick the first non-BlackHole output device as physical default
                    self.targetOutputDevice = devices.first { !$0.isBlackHole }
                }
            }
            .store(in: &cancellables)

        deviceManager.$inputDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$inputDevices)

        deviceManager.$defaultOutputDevice
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dev in
                guard let self, let dev else { return }
                self.defaultOutputDevice = dev
                let hardwareVol = self.deviceManager.getVolume(for: dev.audioDeviceID)
                self.systemOutputVolume = hardwareVol
            }
            .store(in: &cancellables)

        deviceManager.$defaultInputDevice
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dev in
                guard let self, let dev else { return }
                self.defaultInputDevice = dev
                let hardwareVol = self.deviceManager.getVolume(for: dev.audioDeviceID, isInput: true)
                self.systemInputVolume = hardwareVol
            }
            .store(in: &cancellables)

        deviceManager.$defaultSystemOutputDevice
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dev in
                guard let self, let dev else { return }
                self.defaultSystemOutputDevice = dev
                let hardwareVol = self.deviceManager.getVolume(for: dev.audioDeviceID)
                self.soundEffectsVolume = hardwareVol
            }
            .store(in: &cancellables)

        // Load saved favorite bundle IDs
        if let saved = UserDefaults.standard.stringArray(forKey: "SmurfAudio_FavoriteApps") {
            self.favoriteBundleIDs = Set(saved)
        } else {
            // Default favorites common on macOS
            self.favoriteBundleIDs = ["com.apple.Safari", "com.spotify.client", "us.zoom.xos", "com.apple.Music"]
        }

        // Permission check and callbacks
        permissionManager.onPermissionGranted = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                print("[AudioState] TCC ScreenCapture permission granted callback triggered!")
                await self.refreshRunningApps()
                if self.isRoutingActive {
                    try? await self.captureManager.updatePrimaryExclusions(
                        allApps: self.runningApps,
                        engineController: self.engineController
                    )
                }
            }
        }

        // Capture primary meter updates
        captureManager.onPrimaryMeterUpdate = { [weak self] level in
            DispatchQueue.main.async {
                self?.masterMeterLevel = level
            }
        }

        // Set initial engine volume
        engineController.setVolume(systemOutputVolume)

        // Setup Super Volume Keys
        setupMediaKeys()

        // Check TCC Screen Recording permissions at startup
        checkPermissionsAtLaunch()

        // Initial scan for running audio apps
        Task {
            await self.refreshRunningApps()
        }

        // Auto-refresh when apps open or quit
        setupAppWorkspaceObservers()

        // Background check for updates if enabled (suppressed during unit test executions)
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                        NSClassFromString("XCTest") != nil ||
                        ProcessInfo.processInfo.arguments.contains(where: { $0.contains("test") })
        if !isTesting && updateManager.automaticallyChecksForUpdates {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.updateManager.checkForUpdates(silent: true)
            }
        }
    }

    private func setupAppWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshRunningApps() }
        }

        center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshRunningApps() }
        }
    }

    // MARK: - Super Volume Keys

    private func setupMediaKeys() {
        mediaKeyInterceptor.onVolumeUp = { [weak self] in
            guard let self else { return }
            let step: Float = 1.0 / 16.0
            self.systemOutputVolume = min(1.0, self.systemOutputVolume + step)
            self.isMasterMuted = false
        }

        mediaKeyInterceptor.onVolumeDown = { [weak self] in
            guard let self else { return }
            let step: Float = 1.0 / 16.0
            self.systemOutputVolume = max(0.0, self.systemOutputVolume - step)
            if self.systemOutputVolume == 0 {
                self.isMasterMuted = true
            }
        }

        mediaKeyInterceptor.onMuteToggle = { [weak self] in
            guard let self else { return }
            self.isMasterMuted.toggle()
        }

        mediaKeyInterceptor.start()
    }

    // MARK: - Per-App Audio Management

    /// Persists current app settings (volume, mute, boost, pan, EQ, routing) into profile store.
    func persistProfile(for app: AppAudioSource) {
        let deviceUID = outputDevices.first(where: { $0.audioDeviceID == app.selectedOutputDeviceID })?.uid
        let profile = app.makeProfile(targetDeviceUID: deviceUID)
        profileStore.saveProfile(for: app.bundleIdentifier, profile: profile)
    }

    /// Refreshes the list of running user applications capable of audio capture.
    @MainActor
    func refreshRunningApps() async {
        isScanningApps = true
        defer { isScanningApps = false }

        do {
            let discovered = try await captureManager.discoverRunningApps()

            // Stop captures for any apps that terminated
            let terminatedApps = runningApps.filter { existing in
                !discovered.contains { $0.processID == existing.processID }
            }
            for deadApp in terminatedApps where deadApp.isCapturing {
                captureManager.stopCapture(for: deadApp, engineController: engineController)
            }

            // Retain existing capturing sessions if app is still running
            var updated: [AppAudioSource] = []
            for newApp in discovered {
                if let existing = runningApps.first(where: { $0.processID == newApp.processID }) {
                    existing.scApp = newApp.scApp
                    existing.isFavorite = favoriteBundleIDs.contains(existing.bundleIdentifier)
                    updated.append(existing)
                } else {
                    newApp.isFavorite = favoriteBundleIDs.contains(newApp.bundleIdentifier)
                    // Restore saved profile if available
                    if let savedProfile = profileStore.profile(for: newApp.bundleIdentifier) {
                        newApp.applyProfile(savedProfile)
                        if let uid = savedProfile.targetDeviceUID,
                           let match = outputDevices.first(where: { $0.uid == uid }) {
                            newApp.selectedOutputDeviceID = match.audioDeviceID
                        }
                    }
                    updated.append(newApp)
                }
            }

            // Sort: favorites first, then alphabetically
            updated.sort { a, b in
                if a.isFavorite != b.isFavorite {
                    return a.isFavorite && !b.isFavorite
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            self.runningApps = updated

            // Synchronize primary output exclusions if any apps terminated
            if !terminatedApps.isEmpty {
                try? await captureManager.updatePrimaryExclusions(
                    allApps: self.runningApps,
                    engineController: engineController
                )
            }
        } catch {
            print("[AudioState] Error discovering running apps: \(error)")
        }
    }

    // MARK: - Favorites & FX Controls

    func toggleFavorite(for bundleID: String) {
        if favoriteBundleIDs.contains(bundleID) {
            favoriteBundleIDs.remove(bundleID)
        } else {
            favoriteBundleIDs.insert(bundleID)
        }
        UserDefaults.standard.set(Array(favoriteBundleIDs), forKey: "SmurfAudio_FavoriteApps")
        for app in runningApps {
            app.isFavorite = favoriteBundleIDs.contains(app.bundleIdentifier)
        }
        // Re-sort
        runningApps.sort { a, b in
            if a.isFavorite != b.isFavorite {
                return a.isFavorite && !b.isFavorite
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    func selectSystemOutputDevice(_ device: AudioDevice) {
        do {
            try deviceManager.setDefaultSystemOutputDevice(device)
            defaultSystemOutputDevice = device
        } catch {
            print("[AudioState] Failed to set default system output device: \(error)")
        }
    }

    func toggleFX(for id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedFXID == id {
                expandedFXID = nil
            } else {
                expandedFXID = id
            }
        }
    }

    func toggleWindowPin() {
        isWindowPinned.toggle()
        NotificationCenter.default.post(name: NSNotification.Name("TogglePinWindow"), object: nil)
    }

    // MARK: - Permission Controls

    /// Verifies Screen & System Audio Recording permissions on launch.
    /// If declined or not yet granted, presents the dedicated permission popup window.
    func checkPermissionsAtLaunch() {
        let granted = permissionManager.checkScreenCapturePermission()
        if !granted {
            let requested = permissionManager.requestScreenCaptureAccess()
            if !requested {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self else { return }
                    if !self.permissionManager.hasScreenCapturePermission {
                        self.showPermissionWindow()
                    }
                }
            }
        }
    }

    /// Displays the dedicated permission popup window.
    func showPermissionWindow() {
        PermissionWindowController.shared.show(permissionManager: permissionManager)
    }

    /// Displays the dedicated software update window.
    func showUpdateWindow() {
        UpdateWindowController.shared.show(updateManager: updateManager)
    }

    /// Toggles audio capture for an individual application.
    func toggleCapture(for app: AppAudioSource) {
        if app.isCapturing {
            captureManager.stopCapture(for: app, engineController: engineController)
            let remaining = runningApps.filter { $0.isCapturing || $0.selectedOutputDeviceID != nil }.count
            if remaining == 0 && wasAutoRoutedForSecondaryOutput {
                stopRouting()
                wasAutoRoutedForSecondaryOutput = false
            } else {
                Task {
                    try? await captureManager.updatePrimaryExclusions(
                        allApps: runningApps,
                        engineController: engineController
                    )
                }
            }
        } else {
            if !permissionManager.hasScreenCapturePermission {
                if !permissionManager.checkScreenCapturePermission() {
                    showPermissionWindow()
                    app.captureError = "Screen Recording permission required"
                    return
                }
            }

            if !isRoutingActive {
                startRouting()
                wasAutoRoutedForSecondaryOutput = true
            }

            Task {
                do {
                    try await captureManager.startCapture(for: app, engineController: engineController)
                    try await captureManager.updatePrimaryExclusions(
                        allApps: runningApps,
                        engineController: engineController
                    )
                } catch {
                    await MainActor.run {
                        app.captureError = error.localizedDescription
                        let nsError = error as NSError
                        if nsError.code == -3801 || nsError.domain.contains("ScreenCaptureKit") || !self.permissionManager.hasScreenCapturePermission {
                            self.showPermissionWindow()
                        }
                    }
                    print("[AudioState] Failed to capture app \(app.name): \(error)")
                }
            }
        }
    }

    /// Directs an individual application to a specific physical speaker or back to system default.
    func selectAppOutputDevice(app: AppAudioSource, deviceID: AudioDeviceID?) {
        let isRedirecting = (deviceID != nil)

        // Check TCC permission before attempting capture redirection
        if isRedirecting && !permissionManager.hasScreenCapturePermission {
            if !permissionManager.checkScreenCapturePermission() {
                showPermissionWindow()
                app.captureError = "Screen Recording permission required"
                return
            }
        }

        app.selectedOutputDeviceID = deviceID
        persistProfile(for: app)

        // 1. If any app is routed to a secondary speaker, BlackHole must be active
        // so that the app does not play directly to the physical default hardware.
        let redirectedCount = runningApps.filter { $0.selectedOutputDeviceID != nil }.count

        if redirectedCount > 0 && !isRoutingActive {
            startRouting()
            wasAutoRoutedForSecondaryOutput = true
        } else if redirectedCount == 0 && wasAutoRoutedForSecondaryOutput {
            let capturingCount = runningApps.filter { $0.isCapturing }.count
            if capturingCount == 0 {
                stopRouting()
                wasAutoRoutedForSecondaryOutput = false
            }
        }

        // 2. Manage capture and exclusions asynchronously
        Task {
            do {
                if isRedirecting {
                    if app.isCapturing {
                        captureManager.switchOutputDevice(for: app, toDeviceID: deviceID, engineController: engineController)
                    } else {
                        try await captureManager.startCapture(for: app, engineController: engineController)
                    }
                } else {
                    // Reverted to system default
                    if app.isCapturing {
                        captureManager.stopCapture(for: app, engineController: engineController)
                    }
                }

                // 3. Exclude redirected/isolated apps from the primary speaker background mix
                try await captureManager.updatePrimaryExclusions(
                    allApps: runningApps,
                    engineController: engineController
                )
            } catch {
                await MainActor.run {
                    app.captureError = error.localizedDescription
                    let nsError = error as NSError
                    if nsError.code == -3801 || nsError.domain.contains("ScreenCaptureKit") || !self.permissionManager.hasScreenCapturePermission {
                        self.showPermissionWindow()
                    }
                }
                print("[AudioState] Failed to route app \(app.name): \(error)")
            }
        }
    }

    // MARK: - Routing Actions

    /// Toggles the BlackHole -> AVAudioEngine -> Physical output pipeline.
    func toggleGlobalRouting() {
        if isRoutingActive {
            stopRouting()
        } else {
            startRouting()
        }
    }

    func startRouting() {
        guard pipeline.isBlackHoleAvailable else {
            routingError = "BlackHole 2ch driver not detected."
            return
        }

        // Determine destination physical device
        let physicalTarget = targetOutputDevice ?? outputDevices.first { !$0.isBlackHole }
        guard let target = physicalTarget else {
            routingError = "No physical output device found."
            return
        }

        do {
            try pipeline.startRouting(targetPhysical: target)
            try engineController.start(outputDevice: target)
            isRoutingActive = true
            routingError = nil

            // If any apps are currently redirected or capturing, update exclusions
            Task {
                do {
                    try await captureManager.updatePrimaryExclusions(
                        allApps: runningApps,
                        engineController: engineController
                    )
                } catch {
                    let nsError = error as NSError
                    if nsError.code == -3801 || nsError.domain.contains("ScreenCaptureKit") || !self.permissionManager.hasScreenCapturePermission {
                        await MainActor.run {
                            self.showPermissionWindow()
                        }
                    }
                }
            }
        } catch {
            print("[AudioState] Error starting routing: \(error)")
            routingError = error.localizedDescription
            pipeline.stopRouting()
            engineController.stop()
            isRoutingActive = false
        }
    }

    func stopRouting() {
        pipeline.stopRouting()
        engineController.stop()
        captureManager.stopPrimaryStream(engineController: engineController)
        isRoutingActive = false
        routingError = nil
    }

    /// Full teardown of audio routing, event taps, and captures.
    func cleanup() {
        mediaKeyInterceptor.stop()
        captureManager.stopAllCaptures(apps: runningApps, engineController: engineController)
        stopRouting()
    }

    // MARK: - Device Selection

    /// Selects an output device. If routing is active, changes the physical destination.
    /// Otherwise, sets the system default output device.
    func selectOutputDevice(_ device: AudioDevice) {
        targetOutputDevice = device
        if isRoutingActive {
            pipeline.updateTargetDevice(device)
            do {
                try engineController.switchOutputDevice(device)
                // Re-evaluate app routing attachments across engines
                engineController.resynchronizeAppNodes(apps: runningApps)

                // Update hardware volume on the new physical device to match current master volume
                let effectiveVolume = isMasterMuted ? 0.0 : systemOutputVolume
                deviceManager.setVolume(for: device.audioDeviceID, volume: effectiveVolume)

                // Re-apply primary background exclusions
                Task {
                    try? await captureManager.updatePrimaryExclusions(
                        allApps: runningApps,
                        engineController: engineController
                    )
                }
            } catch {
                print("[AudioState] Error switching engine output device: \(error)")
                routingError = error.localizedDescription
            }
        } else {
            do {
                try deviceManager.setDefaultOutputDevice(device)
            } catch {
                print("[AudioState] Failed to set output device: \(error)")
            }
        }
    }

    /// Selects the macOS system default input device.
    func selectInputDevice(_ device: AudioDevice) {
        do {
            try deviceManager.setDefaultInputDevice(device)
        } catch {
            print("[AudioState] Failed to set input device: \(error)")
        }
    }
}
