import Testing
import CoreAudio
import AVFoundation
@testable import SmurfAudio

// MARK: - AudioDevice Tests

@Suite("AudioDevice Tests")
struct AudioDeviceTests {

    @Test("AudioDevice identity and equality based on UID")
    func deviceEqualityAndHashing() {
        let dev1 = AudioDevice(
            audioDeviceID: 101,
            uid: "BuiltInSpeakerDevice",
            name: "MacBook Pro Speakers",
            manufacturer: "Apple Inc.",
            transportType: kAudioDeviceTransportTypeBuiltIn,
            hasInput: false,
            hasOutput: true
        )

        let dev2 = AudioDevice(
            audioDeviceID: 202, // Different session ID
            uid: "BuiltInSpeakerDevice", // Same stable UID
            name: "MacBook Pro Speakers Renamed",
            manufacturer: "Apple",
            transportType: kAudioDeviceTransportTypeBuiltIn,
            hasInput: false,
            hasOutput: true
        )

        let dev3 = AudioDevice(
            audioDeviceID: 303,
            uid: "USBHeadsetUID",
            name: "USB Headset",
            manufacturer: "Logitech",
            transportType: kAudioDeviceTransportTypeUSB,
            hasInput: true,
            hasOutput: true
        )

        #expect(dev1 == dev2)
        #expect(dev1 != dev3)
        #expect(dev1.id == "BuiltInSpeakerDevice")
        #expect(dev1.isOutputDevice == true)
        #expect(dev1.isInputDevice == false)
        #expect(dev3.isInputDevice == true)
        #expect(dev3.isOutputDevice == true)

        var set = Set<AudioDevice>()
        set.insert(dev1)
        set.insert(dev2)
        #expect(set.count == 1)
        set.insert(dev3)
        #expect(set.count == 2)
    }

    @Test("BlackHole detection")
    func blackHoleDetection() {
        let blackHole = AudioDevice(
            audioDeviceID: 55,
            uid: "BlackHole2ch_UID",
            name: "BlackHole 2ch",
            manufacturer: "Existential Audio",
            transportType: kAudioDeviceTransportTypeVirtual,
            hasInput: true,
            hasOutput: true
        )

        let normalSpeaker = AudioDevice(
            audioDeviceID: 60,
            uid: "Speaker_UID",
            name: "External Headphones",
            manufacturer: "Apple Inc.",
            transportType: kAudioDeviceTransportTypeBuiltIn,
            hasInput: false,
            hasOutput: true
        )

        #expect(blackHole.isBlackHole == true)
        #expect(blackHole.systemSymbol == "waveform.path")
        #expect(normalSpeaker.isBlackHole == false)
    }

    @Test("SF Symbol mapping based on transport type")
    func systemSymbols() {
        func makeDevice(transport: UInt32, hasOutput: Bool = true, hasInput: Bool = false) -> AudioDevice {
            AudioDevice(
                audioDeviceID: 1,
                uid: "UID_\(transport)",
                name: "Device",
                manufacturer: "Test",
                transportType: transport,
                hasInput: hasInput,
                hasOutput: hasOutput
            )
        }

        #expect(makeDevice(transport: kAudioDeviceTransportTypeBuiltIn, hasOutput: true, hasInput: false).systemSymbol == "hifispeaker.fill")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeBuiltIn, hasOutput: false, hasInput: true).systemSymbol == "mic.fill")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeUSB).systemSymbol == "cable.connector")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeBluetooth).systemSymbol == "headphones")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeBluetoothLE).systemSymbol == "headphones")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeHDMI).systemSymbol == "display")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeDisplayPort).systemSymbol == "display")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeVirtual).systemSymbol == "waveform")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeAggregate).systemSymbol == "square.stack.3d.up")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeAirPlay).systemSymbol == "airplayaudio")
        #expect(makeDevice(transport: kAudioDeviceTransportTypeThunderbolt).systemSymbol == "bolt.fill")
        #expect(makeDevice(transport: 99999).systemSymbol == "speaker.wave.2.fill")
    }
}

// MARK: - Equalizer & AudioUnitHosting Tests

@Suite("Equalizer and AudioUnitHosting Tests")
struct EqualizerTests {

    @Test("EQBandInfo displayFrequency formatting")
    func bandFrequencyDisplay() {
        let band32 = EQBandInfo(id: 0, frequency: 32, gain: 0, bandwidth: 1.0, filterType: .lowShelf)
        let band500 = EQBandInfo(id: 4, frequency: 500, gain: 0, bandwidth: 1.0, filterType: .parametric)
        let band1k = EQBandInfo(id: 5, frequency: 1000, gain: 0, bandwidth: 1.0, filterType: .parametric)
        let band2_5k = EQBandInfo(id: 6, frequency: 2500, gain: 0, bandwidth: 1.0, filterType: .parametric)
        let band16k = EQBandInfo(id: 9, frequency: 16000, gain: 0, bandwidth: 1.0, filterType: .highShelf)

        #expect(band32.displayFrequency == "32")
        #expect(band500.displayFrequency == "500")
        #expect(band1k.displayFrequency == "1k")
        #expect(band2_5k.displayFrequency == "2.5k")
        #expect(band16k.displayFrequency == "16k")
    }

    @Test("EQPreset definition validation")
    func presetDefinitions() {
        for preset in EQPreset.allCases {
            #expect(preset.gains.count == 10)
            #expect(preset.id == preset.rawValue)
        }

        let flatGains = EQPreset.flat.gains
        #expect(flatGains.allSatisfy { $0 == 0.0 })

        let bassBoostGains = EQPreset.bassBoost.gains
        #expect(bassBoostGains[0] > 0)
        #expect(bassBoostGains[9] == 0)
    }

    @Test("AudioUnitHosting initialization and band setup")
    func audioUnitHostingInit() {
        let hosting = AudioUnitHosting()

        #expect(hosting.bands.count == 10)
        #expect(hosting.isBypassed == false)
        #expect(hosting.selectedPreset == .flat)

        let expectedFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for (i, freq) in expectedFrequencies.enumerated() {
            #expect(hosting.bands[i].frequency == freq)
            #expect(hosting.bands[i].gain == 0.0)
            #expect(hosting.bands[i].bandwidth == 1.0)
        }

        #expect(hosting.bands.first?.filterType == .lowShelf)
        #expect(hosting.bands.last?.filterType == .highShelf)
        for i in 1...8 {
            #expect(hosting.bands[i].filterType == .parametric)
        }
    }

    @Test("AudioUnitHosting gain setting and clamping")
    func gainAdjustment() {
        let hosting = AudioUnitHosting()

        // Normal gain adjustment
        hosting.setGain(forBand: 3, gain: 5.5)
        #expect(hosting.bands[3].gain == 5.5)
        #expect(hosting.eqNode.bands[3].gain == 5.5)

        // Upper clamp at +12 dB
        hosting.setGain(forBand: 3, gain: 18.0)
        #expect(hosting.bands[3].gain == 12.0)
        #expect(hosting.eqNode.bands[3].gain == 12.0)

        // Lower clamp at -12 dB
        hosting.setGain(forBand: 3, gain: -25.0)
        #expect(hosting.bands[3].gain == -12.0)
        #expect(hosting.eqNode.bands[3].gain == -12.0)

        // Out-of-bounds index should safely no-op
        hosting.setGain(forBand: -1, gain: 6.0)
        hosting.setGain(forBand: 99, gain: 6.0)
    }

    @Test("AudioUnitHosting applying presets and resetting")
    func applyPresetsAndReset() {
        let hosting = AudioUnitHosting()

        hosting.selectedPreset = .bassBoost
        #expect(hosting.bands[0].gain == 6.0)
        #expect(hosting.eqNode.bands[0].gain == 6.0)

        hosting.selectedPreset = .trebleBoost
        #expect(hosting.bands[9].gain == 6.0)
        #expect(hosting.eqNode.bands[9].gain == 6.0)

        hosting.resetToFlat()
        #expect(hosting.selectedPreset == .flat)
        for band in hosting.bands {
            #expect(band.gain == 0.0)
        }
    }

    @Test("AudioUnitHosting bypass toggle")
    func bypassToggle() {
        let hosting = AudioUnitHosting()
        #expect(hosting.eqNode.bypass == false)

        hosting.isBypassed = true
        #expect(hosting.eqNode.bypass == true)

        hosting.isBypassed = false
        #expect(hosting.eqNode.bypass == false)
    }
}

// MARK: - AppAudioSource Tests

@Suite("AppAudioSource Tests")
struct AppAudioSourceTests {

    @Test("AppAudioSource initialization")
    func initialization() {
        let app = AppAudioSource(processID: 1234, bundleIdentifier: "com.apple.Music", name: "Music")

        #expect(app.processID == 1234)
        #expect(app.bundleIdentifier == "com.apple.Music")
        #expect(app.name == "Music")
        #expect(app.volume == 1.0)
        #expect(app.isMuted == false)
        #expect(app.isCapturing == false)
        #expect(app.captureError == nil)
        #expect(app.selectedOutputDeviceID == nil)
        #expect(app.playerNode.volume == 1.0)
    }

    @Test("AppAudioSource volume and mute control")
    func volumeAndMuteBehavior() {
        let app = AppAudioSource(processID: 5678, bundleIdentifier: "com.spotify.client", name: "Spotify")

        // Setting volume updates playerNode
        app.volume = 0.65
        #expect(app.playerNode.volume == 0.65)

        // Muting drops playerNode volume to 0 without clearing app.volume
        app.isMuted = true
        #expect(app.isMuted == true)
        #expect(app.playerNode.volume == 0.0)
        #expect(app.volume == 0.65)

        // Adjusting volume while muted updates target volume, playerNode remains muted
        app.volume = 0.40
        #expect(app.volume == 0.40)
        #expect(app.playerNode.volume == 0.0)

        // Unmuting restores the current volume
        app.isMuted = false
        #expect(app.playerNode.volume == 0.40)
    }

    @Test("AppAudioSource output device routing assignment")
    func deviceRoutingAssignment() {
        let app = AppAudioSource(processID: 9999, bundleIdentifier: "com.google.Chrome", name: "Chrome")
        #expect(app.selectedOutputDeviceID == nil)

        app.selectedOutputDeviceID = 42
        #expect(app.selectedOutputDeviceID == 42)

        app.selectedOutputDeviceID = nil
        #expect(app.selectedOutputDeviceID == nil)
    }
}

// MARK: - AudioEngineController Tests

@Suite("AudioEngineController Tests")
struct AudioEngineControllerTests {

    @Test("AudioEngineController volume clamping")
    func volumeClamping() {
        let controller = AudioEngineController()

        controller.setVolume(0.8)
        #expect(controller.currentVolume == 0.8)

        controller.setVolume(1.5)
        #expect(controller.currentVolume == 1.0)

        controller.setVolume(-0.5)
        #expect(controller.currentVolume == 0.0)
    }

    @Test("AudioEngineController primary exclusion lifecycle")
    func primaryCaptureLifecycle() {
        let controller = AudioEngineController()
        #expect(controller.isPrimaryExclusionActive == false)

        controller.disablePrimaryCaptureStream()
        #expect(controller.isPrimaryExclusionActive == false)
        #expect(controller.primarySystemPlayerNode.isPlaying == false)

        controller.stop()
        #expect(controller.isRunning == false)
    }

    @Test("AudioEngineController switch device while secondary engine is attached")
    func switchDeviceWithSecondaryEngine() throws {
        let controller = AudioEngineController()
        let dev126 = AudioDevice(audioDeviceID: 126, uid: "BuiltInSpeakerDevice", name: "Speakers", manufacturer: "Apple", transportType: 0, hasInput: false, hasOutput: true)
        let dev133 = AudioDevice(audioDeviceID: 133, uid: "ZQS-L17", name: "ZQS-L17", manufacturer: "Apple", transportType: 0, hasInput: false, hasOutput: true)

        try controller.start(outputDevice: dev126)
        let primaryNode = controller.enablePrimaryCaptureStream()
        #expect(primaryNode.isPlaying == true)

        let app = AppAudioSource(processID: 1000, bundleIdentifier: "com.test", name: "TestApp")
        controller.attachAppPlayerNode(app.playerNode, eq: app.eq, targetDeviceID: dev133.audioDeviceID, format: nil)
        app.playerNode.play()
        #expect(app.playerNode.isPlaying == true)

        // Switch to dev133
        try controller.switchOutputDevice(dev133)
        #expect(controller.isRunning == true)
        print("primaryNode isPlaying after switch to dev133: \(primaryNode.isPlaying)")
        #expect(primaryNode.isPlaying == true)

        // Switch back to dev126
        try controller.switchOutputDevice(dev126)
        #expect(controller.isRunning == true)
        print("primaryNode isPlaying after switch to dev126: \(primaryNode.isPlaying)")
        #expect(primaryNode.isPlaying == true)

        controller.detachAppPlayerNode(app.playerNode, eq: app.eq)
        controller.stop()
    }
}

// MARK: - CoreAudioHelpers Error Tests

@Suite("CoreAudioHelpers Tests")
struct CoreAudioHelpersTests {

    @Test("CoreAudioError descriptions")
    func errorDescriptions() {
        let notFound = CoreAudioError.propertyNotFound
        #expect(notFound.errorDescription == "CoreAudio property not found")

        let invalidDev = CoreAudioError.invalidDevice
        #expect(invalidDev.errorDescription == "Invalid audio device")

        // 0x6e6f7065 is 'nope'
        let osErr = CoreAudioError.osStatus(1852797029)
        #expect(osErr.errorDescription?.contains("'nope'") == true)
    }
}

// MARK: - Audio Redirection Integration Tests

@Suite("AudioRedirection Integration Tests", .serialized)
struct AudioRedirectionIntegrationTests {

    @Test("BlackHole audio redirection and device restoration lifecycle")
    @MainActor
    func blackHoleRedirectionLifecycle() throws {
        let deviceManager = AudioDeviceManager()
        deviceManager.refreshAllDevices()

        guard let blackHole = deviceManager.outputDevices.first(where: { $0.isBlackHole }) else {
            Issue.record("BlackHole output device not found in CoreAudio")
            return
        }

        guard let originalDefault = deviceManager.defaultOutputDevice else {
            Issue.record("Default output device not detected")
            return
        }

        guard let targetPhysical = deviceManager.outputDevices.first(where: { !$0.isBlackHole }) else {
            Issue.record("Physical output device not found")
            return
        }

        let pipeline = BlackHolePipeline(deviceManager: deviceManager)
        #expect(pipeline.isBlackHoleAvailable == true)

        // 1. Activate routing to BlackHole
        try pipeline.startRouting(targetPhysical: targetPhysical)
        #expect(pipeline.isRoutingActive == true)

        // Verify CoreAudio HAL has switched default output to BlackHole
        let activeDeviceID: AudioDeviceID = try getAudioProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice
        )
        #expect(activeDeviceID == blackHole.audioDeviceID)

        // 2. Stop routing and verify restoration
        pipeline.stopRouting()
        #expect(pipeline.isRoutingActive == false)

        let restoredDeviceID: AudioDeviceID = try getAudioProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice
        )
        #expect(restoredDeviceID == originalDefault.audioDeviceID)
    }

    @Test("Multi-engine output configuration for secondary speaker routing")
    func secondarySpeakerEngineSetup() throws {
        let controller = AudioEngineController()
        let appSource = AppAudioSource(processID: 1000, bundleIdentifier: "com.test.app", name: "TestApp")

        // Test attaching to secondary hardware device
        controller.attachAppPlayerNode(
            appSource.playerNode,
            eq: appSource.eq,
            targetDeviceID: 126, // MacBook Pro Speakers ID
            format: nil
        )

        // Detaching cleans up secondary engine
        controller.detachAppPlayerNode(appSource.playerNode, eq: appSource.eq)
        controller.stop()
        #expect(controller.isRunning == false)
    }
}

// MARK: - AudioState Tests

@Suite("AudioState Tests", .serialized)
@MainActor
struct AudioStateTests {

    @Test("AudioState initial values and master volume update")
    func initialValuesAndVolume() {
        let state = AudioState()
        #expect(state.systemOutputVolume >= 0.0 && state.systemOutputVolume <= 1.0)
        #expect(state.isMasterMuted == false)

        state.systemOutputVolume = 0.42
        #expect(state.systemOutputVolume == 0.42)

        state.systemInputVolume = 0.85
        #expect(state.systemInputVolume == 0.85)
    }

    @Test("AudioState mute toggle and restoration")
    func muteBehavior() {
        let state = AudioState()
        state.systemOutputVolume = 0.60
        #expect(state.isMasterMuted == false)

        state.isMasterMuted = true
        #expect(state.isMasterMuted == true)
        // Original volume state is preserved
        #expect(state.systemOutputVolume == 0.60)

        state.isMasterMuted = false
        #expect(state.isMasterMuted == false)
        #expect(state.systemOutputVolume == 0.60)
    }

    @Test("AudioState routing toggle when BlackHole is available")
    func routingToggle() {
        let state = AudioState()
        let initialRouting = state.isRoutingActive

        if state.isBlackHoleInstalled {
            state.toggleGlobalRouting()
            #expect(state.isRoutingActive != initialRouting)
            state.stopRouting()
            #expect(state.isRoutingActive == false)
        } else {
            state.startRouting()
            #expect(state.routingError != nil)
            #expect(state.isRoutingActive == false)
        }
    }

    @Test("AudioState per-app output device routing state changes")
    func perAppRoutingState() {
        let state = AudioState()
        let app = AppAudioSource(processID: 1234, bundleIdentifier: "com.apple.Music", name: "Music")
        state.runningApps = [app]

        state.selectAppOutputDevice(app: app, deviceID: 99)
        #expect(app.selectedOutputDeviceID == 99)

        state.selectAppOutputDevice(app: app, deviceID: nil)
        #expect(app.selectedOutputDeviceID == nil)
    }

    @Test("Selecting different primary audio while per-app routing is active")
    func appRedirectionThenPrimaryDeviceSwitch() async throws {
        let state = AudioState()
        guard state.isBlackHoleInstalled else { return }

        let physicalSpeakers = state.outputDevices.filter { !$0.isBlackHole }
        guard physicalSpeakers.count >= 2 else {
            print("Skipping test: need at least 2 physical speakers, found \(physicalSpeakers.count)")
            return
        }

        let speakerA = physicalSpeakers[0]
        let speakerB = physicalSpeakers[1]

        let app = AppAudioSource(processID: 1234, bundleIdentifier: "com.apple.Music", name: "Music")
        state.runningApps = [app]

        // 1. Initial primary output is Speaker A
        state.selectOutputDevice(speakerA)
        #expect(state.targetOutputDevice?.audioDeviceID == speakerA.audioDeviceID)

        // 2. Route app to Speaker B
        state.selectAppOutputDevice(app: app, deviceID: speakerB.audioDeviceID)
        #expect(state.isRoutingActive == true)
        #expect(app.selectedOutputDeviceID == speakerB.audioDeviceID)

        // Give async Task time to execute
        try await Task.sleep(nanoseconds: 300_000_000)

        // 3. User selects Speaker B as primary audio
        state.selectOutputDevice(speakerB)

        #expect(state.isRoutingActive == true)
        #expect(state.engineController.isRunning == true)
        #expect(state.routingError == nil)

        // 4. User selects Speaker A as primary audio again
        state.selectOutputDevice(speakerA)
        #expect(state.isRoutingActive == true)
        #expect(state.engineController.isRunning == true)
        #expect(state.routingError == nil)

        state.cleanup()
    }
}


