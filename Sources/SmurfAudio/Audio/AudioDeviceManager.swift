import Foundation
import CoreAudio
import AudioToolbox
import Combine

/// Manages CoreAudio device enumeration, default device selection, and
/// real-time device change notifications (hot-plug, default device changes).
///
/// All ``@Published`` properties are updated on the main thread for SwiftUI safety.
final class AudioDeviceManager: ObservableObject {

    // MARK: - Published State

    /// All connected output-capable audio devices.
    @Published private(set) var outputDevices: [AudioDevice] = []

    /// All connected input-capable audio devices.
    @Published private(set) var inputDevices: [AudioDevice] = []

    /// The current macOS system default output device.
    @Published private(set) var defaultOutputDevice: AudioDevice?

    /// The current macOS system default input device.
    @Published private(set) var defaultInputDevice: AudioDevice?

    /// The current macOS system default sound effects / alerts output device.
    @Published private(set) var defaultSystemOutputDevice: AudioDevice?

    // MARK: - Private

    /// Dispatch queue for CoreAudio property listener callbacks.
    private let listenerQueue = DispatchQueue(
        label: "com.smurfaudio.audio-device-manager",
        qos: .userInitiated
    )

    /// Stored listener references for cleanup in deinit.
    private var installedListeners: [InstalledListener] = []

    /// Bundles the data needed to unregister a CoreAudio property listener.
    private struct InstalledListener {
        let objectID: AudioObjectID
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    // MARK: - Lifecycle

    init() {
        refreshAllDevices()
        installPropertyListeners()
    }

    deinit {
        removeAllListeners()
    }

    // MARK: - Public API

    /// Sets the macOS system default output device.
    ///
    /// The change is picked up by our property listener, which updates
    /// ``defaultOutputDevice`` automatically.
    func setDefaultOutputDevice(_ device: AudioDevice) throws {
        try setAudioProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            value: device.audioDeviceID
        )
    }

    /// Sets the macOS system default input device.
    func setDefaultInputDevice(_ device: AudioDevice) throws {
        try setAudioProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice,
            value: device.audioDeviceID
        )
    }

    /// Sets the macOS system default sound effects / alerts output device.
    func setDefaultSystemOutputDevice(_ device: AudioDevice) throws {
        try setAudioProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            value: device.audioDeviceID
        )
    }

    // MARK: - Physical Hardware Volume Control

    /// Reads the physical device volume (0.0 to 1.0) using VirtualMainVolume.
    func getVolume(for deviceID: AudioDeviceID, isInput: Bool = false) -> Float {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return status == noErr ? volume : 0.5
    }

    /// Sets the physical hardware volume (0.0 to 1.0) directly on the device.
    func setVolume(for deviceID: AudioDeviceID, volume: Float, isInput: Bool = false) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol: Float32 = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
    }

    /// Forces a full refresh of the device list and default devices.
    func refreshAllDevices() {
        do {
            let allDeviceIDs: [AudioDeviceID] = try getAudioPropertyArray(
                objectID: AudioObjectID(kAudioObjectSystemObject),
                selector: kAudioHardwarePropertyDevices
            )

            let devices = allDeviceIDs.compactMap { deviceID -> AudioDevice? in
                do {
                    return try AudioDevice(deviceID: deviceID)
                } catch {
                    print("[AudioDeviceManager] Skipping device \(deviceID): \(error)")
                    return nil
                }
            }

            let outputs = devices.filter(\.isOutputDevice)
            let inputs = devices.filter(\.isInputDevice)

            let updateState = {
                self.outputDevices = outputs
                self.inputDevices = inputs
                self.refreshDefaultDevices()
            }

            if Thread.isMainThread {
                updateState()
            } else {
                DispatchQueue.main.sync {
                    updateState()
                }
            }

        } catch {
            print("[AudioDeviceManager] Failed to enumerate devices: \(error)")
        }
    }

    // MARK: - Default Device Tracking

    private func refreshDefaultDevices() {
        // Default output
        do {
            let outputID: AudioDeviceID = try getAudioProperty(
                objectID: AudioObjectID(kAudioObjectSystemObject),
                selector: kAudioHardwarePropertyDefaultOutputDevice
            )
            defaultOutputDevice = outputDevices.first {
                $0.audioDeviceID == outputID
            } ?? (try? AudioDevice(deviceID: outputID))
        } catch {
            print("[AudioDeviceManager ERROR in refreshDefaultDevices] \(error)")
        }

        // Default input
        if let inputID: AudioDeviceID = try? getAudioProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice
        ) {
            defaultInputDevice = inputDevices.first {
                $0.audioDeviceID == inputID
            } ?? (try? AudioDevice(deviceID: inputID))
        }

        // Default system output (Sound Effects / alerts)
        if let sfxID: AudioDeviceID = try? getAudioProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultSystemOutputDevice
        ) {
            defaultSystemOutputDevice = outputDevices.first {
                $0.audioDeviceID == sfxID
            } ?? (try? AudioDevice(deviceID: sfxID))
        }
    }

    // MARK: - Property Listeners

    private func installPropertyListeners() {
        // 1. Device list changes (USB plug/unplug, Bluetooth connect/disconnect)
        addListener(
            selector: kAudioHardwarePropertyDevices,
            objectID: AudioObjectID(kAudioObjectSystemObject)
        ) { [weak self] in
            self?.refreshAllDevices()
        }

        // 2. Default output device changed (by user in System Settings, or another app)
        addListener(
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            objectID: AudioObjectID(kAudioObjectSystemObject)
        ) { [weak self] in
            DispatchQueue.main.async { self?.refreshDefaultDevices() }
        }

        // 3. Default input device changed
        addListener(
            selector: kAudioHardwarePropertyDefaultInputDevice,
            objectID: AudioObjectID(kAudioObjectSystemObject)
        ) { [weak self] in
            DispatchQueue.main.async { self?.refreshDefaultDevices() }
        }

        // 4. Default system output device changed (Sound Effects / alerts)
        addListener(
            selector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            objectID: AudioObjectID(kAudioObjectSystemObject)
        ) { [weak self] in
            DispatchQueue.main.async { self?.refreshDefaultDevices() }
        }
    }

    /// Registers a block-based CoreAudio property listener and stores it for later removal.
    private func addListener(
        selector: AudioObjectPropertySelector,
        objectID: AudioObjectID,
        handler: @escaping () -> Void
    ) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { _, _ in
            handler()
        }

        let status = AudioObjectAddPropertyListenerBlock(
            objectID, &address, listenerQueue, block
        )

        if status == noErr {
            installedListeners.append(InstalledListener(
                objectID: objectID,
                address: address,
                block: block
            ))
        } else {
            print("[AudioDeviceManager] Failed to add listener for \(selector): \(status)")
        }
    }

    /// Removes all registered property listeners. Called from deinit.
    private func removeAllListeners() {
        for var listener in installedListeners {
            AudioObjectRemovePropertyListenerBlock(
                listener.objectID,
                &listener.address,
                listenerQueue,
                listener.block
            )
        }
        installedListeners.removeAll()
    }
}
