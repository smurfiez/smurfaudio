import Foundation

/// Per-application audio profile storing user volume, mute, boost, pan, and EQ configurations.
struct AppAudioProfile: Codable, Equatable {
    var volume: Float = 1.0
    var isMuted: Bool = false
    var isBoostActive: Bool = false
    var boostGain: Float = 6.0
    var pan: Float = 0.0
    var isMono: Bool = false
    var targetDeviceUID: String? = nil
    var eqPreset: String? = nil
    var eqBandGains: [Float]? = nil
    var isEQBypassed: Bool = false
}

/// Manages persistence of per-application audio settings across launches.
final class AppAudioProfileStore {

    private let userDefaultsKey = "SmurfAudio_AppAudioProfiles"
    private var cachedProfiles: [String: AppAudioProfile] = [:]
    private let queue = DispatchQueue(label: "com.smurfaudio.profilestore", qos: .utility)

    init() {
        loadAllProfiles()
    }

    // MARK: - Loading & Saving

    private func loadAllProfiles() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: AppAudioProfile].self, from: data)
            self.cachedProfiles = decoded
        } catch {
            print("[AppAudioProfileStore] Failed to decode saved profiles: \(error)")
        }
    }

    private func persistToDisk() {
        do {
            let data = try JSONEncoder().encode(cachedProfiles)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("[AppAudioProfileStore] Failed to encode profiles: \(error)")
        }
    }

    // MARK: - Public API

    /// Retrieves the profile for the given app bundle identifier.
    func profile(for bundleIdentifier: String) -> AppAudioProfile? {
        queue.sync {
            cachedProfiles[bundleIdentifier]
        }
    }

    /// Saves or updates the audio profile for the given app bundle identifier.
    func saveProfile(for bundleIdentifier: String, profile: AppAudioProfile) {
        queue.async { [weak self] in
            guard let self else { return }
            self.cachedProfiles[bundleIdentifier] = profile
            self.persistToDisk()
        }
    }

    /// Removes a profile.
    func removeProfile(for bundleIdentifier: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.cachedProfiles.removeValue(forKey: bundleIdentifier)
            self.persistToDisk()
        }
    }

    /// Returns all bundle identifiers that currently have saved profiles.
    func allSavedBundleIDs() -> [String] {
        queue.sync {
            Array(cachedProfiles.keys)
        }
    }
}
