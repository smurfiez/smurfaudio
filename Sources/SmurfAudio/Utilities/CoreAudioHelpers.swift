import Foundation
import CoreAudio

// MARK: - CoreAudio Error Type

/// Wraps CoreAudio `OSStatus` errors into a Swift-native error type.
enum CoreAudioError: Error, LocalizedError {
    case osStatus(OSStatus)
    case propertyNotFound
    case invalidDevice

    var errorDescription: String? {
        switch self {
        case .osStatus(let status):
            return "CoreAudio error: \(status) (\(Self.fourCharDescription(status)))"
        case .propertyNotFound:
            return "CoreAudio property not found"
        case .invalidDevice:
            return "Invalid audio device"
        }
    }

    /// Converts a FourCharCode OSStatus to a readable string (e.g., 'what').
    private static func fourCharDescription(_ status: OSStatus) -> String {
        let bytes = withUnsafeBytes(of: status.bigEndian) { Array($0) }
        if bytes.allSatisfy({ (0x20...0x7E).contains($0) }) {
            return "'" + String(bytes.map { Character(UnicodeScalar($0)) }) + "'"
        }
        return "\(status)"
    }
}

// MARK: - Property Access: Single Value

/// Reads a single fixed-size value from a CoreAudio object property.
///
/// Works with: `AudioDeviceID`, `UInt32`, `Float64`, `AudioClassID`, etc.
/// Does **not** work with variable-size data (use ``getAudioPropertyArray``)
/// or `CFString` (use ``getAudioStringProperty``).
func getAudioProperty<T>(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) throws -> T {
    var address = AudioObjectPropertyAddress(
        mSelector: selector, mScope: scope, mElement: element
    )
    var dataSize = UInt32(MemoryLayout<T>.size)
    let buffer = UnsafeMutableRawPointer.allocate(
        byteCount: Int(dataSize),
        alignment: MemoryLayout<T>.alignment
    )
    defer { buffer.deallocate() }

    let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, buffer)
    guard status == noErr else { throw CoreAudioError.osStatus(status) }

    return buffer.load(as: T.self)
}

/// Writes a single fixed-size value to a CoreAudio object property.
func setAudioProperty<T>(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
    value: T
) throws {
    var address = AudioObjectPropertyAddress(
        mSelector: selector, mScope: scope, mElement: element
    )
    var mutableValue = value
    let dataSize = UInt32(MemoryLayout<T>.size)

    let status = withUnsafeBytes(of: &mutableValue) { buffer -> OSStatus in
        guard let baseAddress = buffer.baseAddress else {
            return kAudioHardwareBadPropertySizeError
        }
        return AudioObjectSetPropertyData(
            objectID, &address, 0, nil, dataSize, baseAddress
        )
    }
    guard status == noErr else { throw CoreAudioError.osStatus(status) }
}

// MARK: - Property Access: Array

/// Reads a variable-length array of fixed-size elements from a CoreAudio object property.
///
/// Works with arrays of `AudioDeviceID`, `AudioStreamID`, etc.
func getAudioPropertyArray<T>(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) throws -> [T] {
    var address = AudioObjectPropertyAddress(
        mSelector: selector, mScope: scope, mElement: element
    )

    // Get total data size
    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize)
    guard status == noErr else { throw CoreAudioError.osStatus(status) }

    let count = Int(dataSize) / MemoryLayout<T>.size
    guard count > 0 else { return [] }

    // Allocate and read
    let buffer = UnsafeMutablePointer<T>.allocate(capacity: count)
    defer { buffer.deallocate() }

    status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, buffer)
    guard status == noErr else { throw CoreAudioError.osStatus(status) }

    return Array(UnsafeBufferPointer(start: buffer, count: count))
}

// MARK: - Property Access: String

/// Reads a `CFString` property from a CoreAudio object and returns it as a Swift `String`.
///
/// Used for device name, UID, manufacturer, etc.
func getAudioStringProperty(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) throws -> String {
    var address = AudioObjectPropertyAddress(
        mSelector: selector, mScope: scope, mElement: element
    )
    var unmanagedString: Unmanaged<CFString>?
    var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

    let status = withUnsafeMutablePointer(to: &unmanagedString) { ptr in
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, ptr)
    }
    guard status == noErr, let unmanaged = unmanagedString else {
        throw CoreAudioError.osStatus(status)
    }

    return unmanaged.takeRetainedValue() as String
}

// MARK: - Property Access: Data Size

/// Returns the data size (in bytes) for a CoreAudio object property.
///
/// Useful for checking whether a property exists or has any data
/// without actually reading it.
func getAudioPropertyDataSize(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) -> UInt32 {
    var address = AudioObjectPropertyAddress(
        mSelector: selector, mScope: scope, mElement: element
    )
    var dataSize: UInt32 = 0
    AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize)
    return dataSize
}
