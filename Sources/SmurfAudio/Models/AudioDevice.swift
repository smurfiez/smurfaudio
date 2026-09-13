import Foundation
import CoreAudio

/// Represents a physical or virtual audio device discovered via CoreAudio.
///
/// Each device has a unique ``uid`` (stable across reboots) and a session-specific
/// ``audioDeviceID`` (valid only while the device is connected).
struct AudioDevice: Identifiable, Hashable {

    /// The CoreAudio device ID (session-specific, may change between connections).
    let audioDeviceID: AudioDeviceID

    /// Persistent unique identifier (stable across reboots).
    let uid: String

    /// Human-readable device name (e.g., "MacBook Pro Speakers").
    let name: String

    /// Device manufacturer name.
    let manufacturer: String

    /// Transport type (built-in, USB, Bluetooth, HDMI, virtual, etc.).
    let transportType: UInt32

    /// Whether this device supports audio input.
    let hasInput: Bool

    /// Whether this device supports audio output.
    let hasOutput: Bool

    // MARK: - Identifiable

    /// Uses the stable UID for SwiftUI identity.
    var id: String { uid }

    // MARK: - Convenience

    var isOutputDevice: Bool { hasOutput }
    var isInputDevice: Bool { hasInput }

    /// Returns `true` if this device is a BlackHole virtual device.
    var isBlackHole: Bool { uid.hasPrefix("BlackHole") }

    /// SF Symbol name appropriate for this device's transport type.
    var systemSymbol: String {
        if isBlackHole { return "waveform.path" }

        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            return hasOutput ? "hifispeaker.fill" : "mic.fill"
        case kAudioDeviceTransportTypeUSB:
            return "cable.connector"
        case kAudioDeviceTransportTypeBluetooth,
             kAudioDeviceTransportTypeBluetoothLE:
            return "headphones"
        case kAudioDeviceTransportTypeHDMI,
             kAudioDeviceTransportTypeDisplayPort:
            return "display"
        case kAudioDeviceTransportTypeVirtual:
            return "waveform"
        case kAudioDeviceTransportTypeAggregate:
            return "square.stack.3d.up"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeThunderbolt:
            return "bolt.fill"
        default:
            return "speaker.wave.2.fill"
        }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }

    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.uid == rhs.uid
    }
}

// MARK: - CoreAudio Initialization

extension AudioDevice {

    /// Creates an ``AudioDevice`` by reading properties from a CoreAudio device ID.
    ///
    /// - Parameter deviceID: The `AudioDeviceID` to query.
    /// - Throws: ``CoreAudioError`` if required properties (name, UID) cannot be read.
    init(deviceID: AudioDeviceID) throws {
        self.audioDeviceID = deviceID

        self.name = try getAudioStringProperty(
            objectID: deviceID,
            selector: kAudioObjectPropertyName
        )

        self.uid = try getAudioStringProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyDeviceUID
        )

        self.manufacturer = (try? getAudioStringProperty(
            objectID: deviceID,
            selector: kAudioObjectPropertyManufacturer
        )) ?? "Unknown"

        self.transportType = (try? getAudioProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyTransportType
        ) as UInt32) ?? 0

        self.hasInput = Self.hasStreamsInScope(
            deviceID: deviceID,
            scope: kAudioObjectPropertyScopeInput
        )
        self.hasOutput = Self.hasStreamsInScope(
            deviceID: deviceID,
            scope: kAudioObjectPropertyScopeOutput
        )
    }

    /// Checks whether a device has any audio streams in the given scope.
    ///
    /// A non-zero data size for `kAudioDevicePropertyStreams` means the device
    /// supports that direction (input or output).
    private static func hasStreamsInScope(
        deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> Bool {
        let dataSize = getAudioPropertyDataSize(
            objectID: deviceID,
            selector: kAudioDevicePropertyStreams,
            scope: scope
        )
        return dataSize > 0
    }
}
