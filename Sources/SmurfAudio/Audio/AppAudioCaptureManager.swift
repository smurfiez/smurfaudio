import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

/// Coordinates ScreenCaptureKit audio streams for individual running applications.
///
/// Features:
/// - Discovers running interactive user applications via `SCShareableContent`.
/// - Creates isolated `SCStream` capture pipelines for selected apps.
/// - Transforms `CMSampleBuffer` frames into `AVAudioPCMBuffer` instances.
/// - Schedules buffers directly onto each application's `AVAudioPlayerNode`.
final class AppAudioCaptureManager {

    // MARK: - Private State

    private let audioProcessingQueue = DispatchQueue(
        label: "com.smurfaudio.screencapture.audio",
        qos: .userInteractive
    )

    /// Retains stream output handlers to prevent premature deallocation.
    private var streamHandlers: [UUID: AppStreamOutputHandler] = [:]

    // MARK: - Primary Exclusion Stream State

    private var primaryStream: SCStream?
    private var primaryHandler: PrimaryStreamOutputHandler?
    private var currentExcludedPIDs: Set<pid_t> = []

    // MARK: - App Discovery

    /// Queries macOS for currently running user-facing applications eligible for audio capture.
    /// Uses NSWorkspace so apps are discovered immediately without requiring Screen Recording permission upfront.
    func discoverRunningApps() async throws -> [AppAudioSource] {
        // 1. Enumerate all active GUI applications via NSWorkspace
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular,
                  let bundle = app.bundleIdentifier,
                  let name = app.localizedName,
                  !name.isEmpty else {
                return false
            }
            if app.processIdentifier == currentPID { return false }

            let bundleID = bundle.lowercased()
            if bundleID.hasPrefix("com.apple.systempreferences") {
                return false
            }
            return true
        }

        // Construct AppAudioSource instances without querying ScreenCaptureKit
        return runningApps.map { app in
            AppAudioSource(
                processID: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier ?? "",
                name: app.localizedName ?? "Unknown"
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Capture Control

    private var activeStartingCaptures = Set<pid_t>()

    /// Safely attaches and configures an app's player node under nodeLock protection.
    private func safelyAttachNode(
        source: AppAudioSource,
        engineController: AudioEngineController,
        targetDeviceID: AudioDeviceID?,
        format: AVAudioFormat?
    ) {
        source.nodeLock.lock()
        defer { source.nodeLock.unlock() }

        engineController.attachAppPlayerNode(
            source.playerNode,
            eq: source.eq,
            targetDeviceID: targetDeviceID,
            format: format
        )
        if let engine = source.playerNode.engine, engine.isRunning {
            source.playerNode.play()
        }
    }

    /// Safely stops and detaches an app's player node under nodeLock protection.
    private func safelyDetachNode(
        source: AppAudioSource,
        engineController: AudioEngineController
    ) {
        source.nodeLock.lock()
        defer { source.nodeLock.unlock() }

        source.playerNode.stop()
        engineController.detachAppPlayerNode(source.playerNode, eq: source.eq)
    }

    /// Starts an isolated audio capture stream for the given application.
    func startCapture(for source: AppAudioSource, engineController: AudioEngineController) async throws {
        guard !source.isCapturing else { return }
        guard !activeStartingCaptures.contains(source.processID) else { return }
        activeStartingCaptures.insert(source.processID)
        defer { activeStartingCaptures.remove(source.processID) }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw CoreAudioError.invalidDevice
        }

        // Locate current SCRunningApplication matching this PID
        guard let scApp = content.applications.first(where: { $0.processID == source.processID }) ?? source.scApp else {
            throw CoreAudioError.invalidDevice
        }
        source.scApp = scApp

        // 1. Create content filter focused specifically on this app
        let filter = SCContentFilter(display: display, including: [scApp], exceptingWindows: [])

        // 2. Configure audio-only stream parameters (with minimal 2x2 dummy video dimensions)
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        // Standard 48kHz stereo format
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)

        // Clean up any existing stream before starting a new one
        if let existingStream = source.stream {
            if let existingHandler = streamHandlers.removeValue(forKey: source.id) {
                existingHandler.invalidate()
            }
            existingStream.stopCapture { _ in }
            source.stream = nil
        }

        // 3. Attach app's playerNode into the AVAudioEngine graph and start playing
        safelyAttachNode(
            source: source,
            engineController: engineController,
            targetDeviceID: source.selectedOutputDeviceID,
            format: audioFormat
        )

        // 4. Create SCStream and register output handler
        let handler = AppStreamOutputHandler(source: source, defaultFormat: audioFormat)
        let stream = SCStream(filter: filter, configuration: config, delegate: handler)
        try stream.addStreamOutput(handler, type: .audio, sampleHandlerQueue: audioProcessingQueue)

        try await stream.startCapture()

        source.stream = stream
        streamHandlers[source.id] = handler

        await MainActor.run {
            source.isCapturing = true
            source.captureError = nil
        }
        print("[AppAudioCaptureManager] Started capturing audio for \(source.name) (PID: \(source.processID))")
    }

    /// Dynamically redirects an app's audio stream to a different physical speaker.
    func switchOutputDevice(
        for source: AppAudioSource,
        toDeviceID: AudioDeviceID?,
        engineController: AudioEngineController
    ) {
        source.selectedOutputDeviceID = toDeviceID
        guard source.isCapturing else { return }

        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)
        safelyAttachNode(
            source: source,
            engineController: engineController,
            targetDeviceID: toDeviceID,
            format: audioFormat
        )
        print("[AppAudioCaptureManager] Switched output device for \(source.name) to: \(String(describing: toDeviceID))")
    }

    /// Stops audio capture for the given application.
    func stopCapture(for source: AppAudioSource, engineController: AudioEngineController) {
        guard source.isCapturing else { return }

        // Immediately invalidate handler so any in-flight buffers are dropped
        if let handler = streamHandlers.removeValue(forKey: source.id) {
            handler.invalidate()
        }

        if let stream = source.stream {
            stream.stopCapture { error in
                if let error {
                    print("[AppAudioCaptureManager] Error stopping stream: \(error)")
                }
            }
        }
        source.stream = nil

        safelyDetachNode(source: source, engineController: engineController)

        DispatchQueue.main.async {
            source.isCapturing = false
        }
        print("[AppAudioCaptureManager] Stopped capturing audio for \(source.name)")
    }

    // MARK: - Primary Audio Exclusion Capture

    /// Synchronizes the primary output audio stream, excluding any applications that are routed to separate speakers or isolated.
    func updatePrimaryExclusions(
        allApps: [AppAudioSource],
        engineController: AudioEngineController
    ) async throws {
        guard engineController.isRunning else {
            stopPrimaryStream(engineController: engineController)
            return
        }

        // Apps to exclude from primary background stream:
        // 1. Any app routed to a separate speaker (selectedOutputDeviceID != nil).
        // 2. Any app actively isolated for per-app mixing (selectedOutputDeviceID == nil && isCapturing).
        let appsToExclude = allApps.filter { app in
            app.selectedOutputDeviceID != nil || app.isCapturing
        }

        let newExcludedPIDs = Set(appsToExclude.map { $0.processID })

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw CoreAudioError.invalidDevice
        }

        // Resolve SCRunningApplication instances for excluded apps
        var scAppsToExclude: [SCRunningApplication] = []
        for app in appsToExclude {
            if let scApp = content.applications.first(where: { $0.processID == app.processID }) ?? app.scApp {
                app.scApp = scApp
                scAppsToExclude.append(scApp)
            }
        }

        let filter = SCContentFilter(display: display, excludingApplications: scAppsToExclude, exceptingWindows: [])

        if let existingStream = primaryStream {
            // Dynamically update the filter of the running primary stream
            if newExcludedPIDs != currentExcludedPIDs {
                try await existingStream.updateContentFilter(filter)
                currentExcludedPIDs = newExcludedPIDs
                print("[AppAudioCaptureManager] Updated primary exclusion filter. Excluded apps: \(scAppsToExclude.map { $0.applicationName })")
            }
        } else {
            // Activate primary exclusion stream
            let playerNode = engineController.enablePrimaryCaptureStream()

            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)
            let handler = PrimaryStreamOutputHandler(playerNode: playerNode, defaultFormat: audioFormat)
            let stream = SCStream(filter: filter, configuration: config, delegate: handler)
            try stream.addStreamOutput(handler, type: .audio, sampleHandlerQueue: audioProcessingQueue)

            try await stream.startCapture()

            self.primaryStream = stream
            self.primaryHandler = handler
            self.currentExcludedPIDs = newExcludedPIDs
            print("[AppAudioCaptureManager] Started primary exclusion stream. Excluded apps: \(scAppsToExclude.map { $0.applicationName })")
        }
    }

    /// Stops the primary exclusion stream and restores direct pass-through on the primary output engine.
    func stopPrimaryStream(engineController: AudioEngineController) {
        if let stream = primaryStream {
            primaryHandler?.invalidate()
            stream.stopCapture { error in
                if let error {
                    print("[AppAudioCaptureManager] Error stopping primary stream: \(error)")
                }
            }
            primaryStream = nil
            primaryHandler = nil
            currentExcludedPIDs.removeAll()
        }
        engineController.disablePrimaryCaptureStream()
        print("[AppAudioCaptureManager] Primary exclusion stream stopped.")
    }

    /// Stops all ongoing capture streams including the primary exclusion stream.
    func stopAllCaptures(apps: [AppAudioSource], engineController: AudioEngineController) {
        for app in apps where app.isCapturing {
            stopCapture(for: app, engineController: engineController)
        }
        stopPrimaryStream(engineController: engineController)
    }
}

// MARK: - Primary Stream Output Delegate

/// Receives audio buffers from the primary exclusion ScreenCaptureKit stream and schedules them onto the primary player node.
private final class PrimaryStreamOutputHandler: NSObject, SCStreamOutput, SCStreamDelegate {
    private weak var playerNode: AVAudioPlayerNode?
    private let defaultFormat: AVAudioFormat?
    private(set) var isInvalidated: Bool = false

    init(playerNode: AVAudioPlayerNode, defaultFormat: AVAudioFormat?) {
        self.playerNode = playerNode
        self.defaultFormat = defaultFormat
    }

    func invalidate() {
        isInvalidated = true
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !isInvalidated else { return }
        guard type == .audio, sampleBuffer.isValid else { return }
        guard let pcmBuffer = AppStreamOutputHandler.pcmBuffer(from: sampleBuffer, fallbackFormat: defaultFormat) else { return }
        guard let player = self.playerNode else { return }
        guard let engine = player.engine, engine.isRunning else { return }

        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(pcmBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("[PrimaryStreamOutputHandler] Primary stream stopped with error: \(error)")
    }
}

// MARK: - Stream Output Delegate

/// Receives audio sample buffers from ScreenCaptureKit and forwards them to AVAudioPlayerNode.
private final class AppStreamOutputHandler: NSObject, SCStreamOutput, SCStreamDelegate {
    private weak var source: AppAudioSource?
    private let defaultFormat: AVAudioFormat?
    private(set) var isInvalidated: Bool = false

    init(source: AppAudioSource, defaultFormat: AVAudioFormat?) {
        self.source = source
        self.defaultFormat = defaultFormat
    }

    func invalidate() {
        isInvalidated = true
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !isInvalidated else { return }
        guard type == .audio, sampleBuffer.isValid else { return }
        guard let pcmBuffer = Self.pcmBuffer(from: sampleBuffer, fallbackFormat: defaultFormat) else { return }

        guard let source = self.source else { return }

        // Use try() on audio thread to avoid blocking; if node is undergoing attachment/detachment, skip frame safely
        guard source.nodeLock.try() else { return }
        defer { source.nodeLock.unlock() }

        guard !isInvalidated else { return }

        // Verify playerNode is still attached to a valid, running engine
        guard let engine = source.playerNode.engine, engine.isRunning else {
            return
        }

        if !source.playerNode.isPlaying {
            source.playerNode.play()
        }
        source.playerNode.scheduleBuffer(pcmBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("[AppStreamOutputHandler] Stream stopped with error: \(error)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let source = self.source else { return }
            source.isCapturing = false
            let nsError = error as NSError
            if nsError.code == -3817 { // SCStreamErrorUserStopped
                source.captureError = nil
            } else if nsError.code == -3801 {
                source.captureError = "Screen Recording permission declined"
            } else {
                source.captureError = error.localizedDescription
            }
        }
    }

    // MARK: - Buffer Conversion

    fileprivate static func pcmBuffer(from sampleBuffer: CMSampleBuffer, fallbackFormat: AVAudioFormat?) -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }

        let targetFormat: AVAudioFormat
        if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
            var mutableDesc = asbd
            guard let avFormat = AVAudioFormat(streamDescription: &mutableDesc) else { return nil }
            targetFormat = avFormat
        } else if let fallbackFormat {
            targetFormat = fallbackFormat
        } else {
            return nil
        }

        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0,
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return nil
        }

        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(pcmBuffer.frameLength),
            into: pcmBuffer.mutableAudioBufferList
        )
        guard status == noErr else { return nil }
        return pcmBuffer
    }
}
