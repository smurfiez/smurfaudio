import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox

/// Manages multi-engine audio routing graphs for real-time system and per-app audio redirection.
///
/// Supports routing different applications to completely separate physical speakers simultaneously.
final class AudioEngineController: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentVolume: Float = 1.0

    // MARK: - Primary Audio Engine Components (System Default Output)

    private let engine = AVAudioEngine()
    private let globalMixer = AVAudioMixerNode()
    private let appMixer = AVAudioMixerNode()

    /// Dedicated player node receiving system audio with redirected applications excluded.
    let primarySystemPlayerNode = AVAudioPlayerNode()

    /// Tracks whether the ScreenCaptureKit primary exclusion stream is active.
    private(set) var isPrimaryExclusionActive: Bool = false

    /// The master 10-band equalizer node
    let eqHosting = AudioUnitHosting()

    private var currentTargetDevice: AudioDevice?

    // MARK: - Secondary Audio Engines (Per-App Separate Speaker Routing)

    /// Dedicated engines driving separate physical audio hardware devices.
    private var secondaryEngines: [AudioDeviceID: DeviceOutputEngine] = [:]

    /// Tracks which engine each player node is currently attached to.
    private var nodeEngineMap: [ObjectIdentifier: AudioDeviceID?] = [:]

    // MARK: - Initialization

    init() {
        setupGraph()
    }

    deinit {
        stop()
    }

    // MARK: - Audio Graph Setup

    private func setupGraph() {
        // Attach intermediate mixers, primary capture node, and EQ unit
        engine.attach(globalMixer)
        engine.attach(appMixer)
        engine.attach(primarySystemPlayerNode)
        engine.attach(eqHosting.eqNode)

        let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)

        // Connect intermediate mixers to mainMixerNode
        engine.connect(globalMixer, to: engine.mainMixerNode, format: standardFormat)
        engine.connect(appMixer, to: engine.mainMixerNode, format: standardFormat)

        // Connect primary exclusion capture player node to globalMixer
        engine.connect(primarySystemPlayerNode, to: globalMixer, format: standardFormat)

        // Route mainMixerNode through master EQ into outputNode
        engine.connect(engine.mainMixerNode, to: eqHosting.eqNode, format: standardFormat)
        engine.connect(eqHosting.eqNode, to: engine.outputNode, format: standardFormat)
    }

    // MARK: - Primary Exclusion Stream Control

    /// Prepares and activates the primary system player node for exclusion capture.
    func enablePrimaryCaptureStream() -> AVAudioPlayerNode {
        isPrimaryExclusionActive = true

        if !engine.isRunning {
            if let output = currentTargetDevice {
                try? setOutputNodeDevice(output.audioDeviceID)
            }
            engine.prepare()
            try? engine.start()
            isRunning = true
        }

        if !primarySystemPlayerNode.isPlaying {
            primarySystemPlayerNode.play()
        }

        print("[AudioEngineController] Enabled primary exclusion stream playback")
        return primarySystemPlayerNode
    }

    /// Disables the primary system player node.
    func disablePrimaryCaptureStream() {
        isPrimaryExclusionActive = false
        primarySystemPlayerNode.stop()
        print("[AudioEngineController] Disabled primary exclusion stream playback")
    }

    // MARK: - Engine Lifecycle

    /// Configures the master physical output destination and starts the audio engine.
    func start(outputDevice: AudioDevice) throws {
        currentTargetDevice = outputDevice

        // Assign hardware output device to AVAudioEngine outputNode
        try setOutputNodeDevice(outputDevice.audioDeviceID)

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
        isRunning = true
        print("[AudioEngineController] Started primary output engine: \(outputDevice.name)")
    }

    /// Stops the primary audio engine and all secondary engines.
    func stop() {
        primarySystemPlayerNode.stop()

        for (_, secEngine) in secondaryEngines {
            secEngine.stop()
        }
        secondaryEngines.removeAll()
        nodeEngineMap.removeAll()

        engine.stop()
        isRunning = false
        print("[AudioEngineController] Engine fully stopped")
    }

    // MARK: - Per-App Player Nodes & Separate Speaker Routing

    /// Attaches an app's player node and dedicated EQ into either the primary engine or a secondary speaker engine.
    func attachAppPlayerNode(
        _ node: AVAudioPlayerNode,
        eq: AudioUnitHosting,
        targetDeviceID: AudioDeviceID?,
        format: AVAudioFormat?
    ) {
        // Detach from previous engine if needed
        detachAppPlayerNode(node, eq: eq)
        nodeEngineMap[ObjectIdentifier(node)] = targetDeviceID

        if let targetID = targetDeviceID, targetID != currentTargetDevice?.audioDeviceID {
            // Route to secondary speaker engine
            let secEngine = secondaryEngines[targetID] ?? {
                let e = DeviceOutputEngine(deviceID: targetID)
                secondaryEngines[targetID] = e
                return e
            }()
            secEngine.attachApp(node, eq: eq, format: format)
            print("[AudioEngineController] Attached app to secondary speaker ID: \(targetID)")
        } else {
            // Route to primary master engine
            engine.attach(node)
            engine.attach(eq.eqNode)
            engine.connect(node, to: eq.eqNode, format: format)
            engine.connect(eq.eqNode, to: appMixer, format: format)

            if !engine.isRunning {
                if let output = currentTargetDevice {
                    try? setOutputNodeDevice(output.audioDeviceID)
                }
                engine.prepare()
                try? engine.start()
                isRunning = true
            }
            print("[AudioEngineController] Attached app to primary output")
        }
    }

    /// Detaches an app's player node and EQ from whatever engine it is currently routed to.
    func detachAppPlayerNode(_ node: AVAudioPlayerNode, eq: AudioUnitHosting) {
        guard let currentTarget = nodeEngineMap.removeValue(forKey: ObjectIdentifier(node)) else {
            return
        }

        if let targetID = currentTarget, targetID != currentTargetDevice?.audioDeviceID {
            secondaryEngines[targetID]?.detachApp(node, eq: eq)
            if secondaryEngines[targetID]?.activeAppCount == 0 {
                secondaryEngines[targetID]?.stop()
                secondaryEngines.removeValue(forKey: targetID)
            }
        } else {
            node.stop()
            engine.disconnectNodeOutput(node)
            engine.disconnectNodeOutput(eq.eqNode)
            engine.detach(node)
            engine.detach(eq.eqNode)
        }
    }

    // MARK: - Device Routing

    /// Dynamically switches the master physical output device without recreating the entire graph.
    func switchOutputDevice(_ newOutputDevice: AudioDevice) throws {
        guard newOutputDevice.audioDeviceID != currentTargetDevice?.audioDeviceID else { return }

        let wasRunning = engine.isRunning
        if wasRunning {
            engine.stop()
        }

        // If a secondary engine was driving this device, stop and dismantle it so primary engine can take over
        if let existingSecEngine = secondaryEngines.removeValue(forKey: newOutputDevice.audioDeviceID) {
            existingSecEngine.stop()
        }

        try setOutputNodeDevice(newOutputDevice.audioDeviceID)
        currentTargetDevice = newOutputDevice

        if wasRunning {
            engine.prepare()
            try engine.start()
            isRunning = true

            // When engine stops, player nodes transition to stopped state. Re-trigger play if stream was active.
            if isPrimaryExclusionActive && !primarySystemPlayerNode.isPlaying {
                primarySystemPlayerNode.play()
            }
        }
        print("[AudioEngineController] Switched output device to: \(newOutputDevice.name)")
    }

    /// Resynchronizes all running apps with the proper audio engines based on currentTargetDevice.
    func resynchronizeAppNodes(apps: [AppAudioSource]) {
        for app in apps where app.isCapturing {
            // Re-attaching will cleanly detach from any old/conflicted engine and attach to the appropriate one
            attachAppPlayerNode(
                app.playerNode,
                eq: app.eq,
                targetDeviceID: app.selectedOutputDeviceID,
                format: app.playerNode.outputFormat(forBus: 0)
            )
            if !app.playerNode.isPlaying {
                app.playerNode.play()
            }
        }
    }

    // MARK: - Volume Control

    /// Adjusts the global audio volume (0.0 to 1.0).
    func setVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        currentVolume = clamped
        globalMixer.outputVolume = clamped
    }

    /// Adjusts master output volume across both global and app streams.
    func setMasterVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        engine.mainMixerNode.outputVolume = clamped
    }

    // MARK: - Internal HAL AudioUnit Configuration


    private func setOutputNodeDevice(_ deviceID: AudioDeviceID) throws {
        guard let outputUnit = engine.outputNode.audioUnit else {
            throw CoreAudioError.invalidDevice
        }

        var devID = deviceID
        let status = AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw CoreAudioError.osStatus(status) }
    }
}

// MARK: - Secondary Device Output Engine

/// An independent AVAudioEngine powering a dedicated physical speaker (e.g. Bluetooth, Headphones).
final class DeviceOutputEngine {
    let deviceID: AudioDeviceID
    let engine = AVAudioEngine()
    let mixer = AVAudioMixerNode()
    private(set) var isRunning: Bool = false
    private(set) var activeAppCount: Int = 0

    init(deviceID: AudioDeviceID) {
        self.deviceID = deviceID
        setup()
    }

    deinit {
        stop()
    }

    private func setup() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        // Bind outputNode to this specific hardware deviceID
        if let outputUnit = engine.outputNode.audioUnit {
            var devID = deviceID
            AudioUnitSetProperty(
                outputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &devID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }
    }

    func attachApp(_ node: AVAudioPlayerNode, eq: AudioUnitHosting, format: AVAudioFormat?) {
        engine.attach(node)
        engine.attach(eq.eqNode)
        engine.connect(node, to: eq.eqNode, format: format)
        engine.connect(eq.eqNode, to: mixer, format: format)
        activeAppCount += 1

        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
                isRunning = true
            } catch {
                print("[DeviceOutputEngine] Failed to start engine for device \(deviceID): \(error)")
                isRunning = false
            }
        }
    }

    func detachApp(_ node: AVAudioPlayerNode, eq: AudioUnitHosting) {
        node.stop()
        engine.disconnectNodeOutput(node)
        engine.disconnectNodeOutput(eq.eqNode)
        engine.detach(node)
        engine.detach(eq.eqNode)
        activeAppCount = max(0, activeAppCount - 1)

        if activeAppCount == 0 {
            engine.stop()
            isRunning = false
        }
    }

    func stop() {
        engine.stop()
        isRunning = false
    }
}
