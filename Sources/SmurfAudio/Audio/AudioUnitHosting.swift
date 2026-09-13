import Foundation
import AVFoundation
import AudioToolbox

// MARK: - EQ Band Model

/// Represents a single frequency band in a graphic/parametric equalizer.
struct EQBandInfo: Identifiable {
    let id: Int
    let frequency: Float       // In Hertz (e.g., 1000 Hz)
    var gain: Float            // In decibels (-12 dB to +12 dB)
    var bandwidth: Float       // In octaves (default 1.0)
    var filterType: AVAudioUnitEQFilterType

    var displayFrequency: String {
        if frequency >= 1000 {
            let khz = frequency / 1000.0
            return khz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(khz))k" : String(format: "%.1fk", khz)
        } else {
            return "\(Int(frequency))"
        }
    }
}

// MARK: - EQ Presets

enum EQPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case trebleBoost = "Treble Boost"
    case vocal = "Vocal Clarity"
    case electronic = "Electronic"
    case acoustic = "Acoustic"

    var id: String { rawValue }

    /// Gains for 10 standard octave bands: [32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz]
    var gains: [Float] {
        switch self {
        case .flat:
            return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bassBoost:
            return [6, 5.5, 4.5, 3, 1, 0, 0, 0, 0, 0]
        case .trebleBoost:
            return [0, 0, 0, 0, 0, 1, 2.5, 4, 5.5, 6]
        case .vocal:
            return [-2, -2, -1, 1.5, 4, 4.5, 3.5, 2, 0, -1]
        case .electronic:
            return [5, 4.5, 2, 0, -1, 1.5, 2, 3.5, 4.5, 5]
        case .acoustic:
            return [3.5, 3, 2, 1, 1.5, 2, 2.5, 3, 3, 2]
        }
    }
}

// MARK: - Audio Unit EQ Manager

/// Hosts and configures an `AVAudioUnitEQ` node with 10 parametric frequency bands.
final class AudioUnitHosting: ObservableObject {

    // MARK: - Published State

    @Published var isBypassed: Bool = false {
        didSet {
            eqNode.bypass = isBypassed
        }
    }

    @Published var selectedPreset: EQPreset = .flat {
        didSet {
            applyPreset(selectedPreset)
        }
    }

    @Published var bands: [EQBandInfo] = []

    // MARK: - Audio Unit Node

    /// The underlying CoreAudio / AVFoundation AudioUnit EQ node.
    let eqNode: AVAudioUnitEQ

    private static let standardFrequencies: [Float] = [
        32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
    ]

    // MARK: - Initialization

    init() {
        let count = Self.standardFrequencies.count
        self.eqNode = AVAudioUnitEQ(numberOfBands: count)

        // Initialize 10 standard octave bands
        var initialBands: [EQBandInfo] = []
        for (index, freq) in Self.standardFrequencies.enumerated() {
            let filterType: AVAudioUnitEQFilterType
            if index == 0 {
                filterType = .lowShelf
            } else if index == count - 1 {
                filterType = .highShelf
            } else {
                filterType = .parametric
            }

            let bandParam = eqNode.bands[index]
            bandParam.frequency = freq
            bandParam.gain = 0.0
            bandParam.bandwidth = 1.0
            bandParam.filterType = filterType
            bandParam.bypass = false

            initialBands.append(EQBandInfo(
                id: index,
                frequency: freq,
                gain: 0.0,
                bandwidth: 1.0,
                filterType: filterType
            ))
        }

        self.bands = initialBands
        self.eqNode.bypass = false
    }

    // MARK: - Band Adjustments

    /// Adjusts the gain in decibels for a specific band (-12 dB to +12 dB).
    func setGain(forBand index: Int, gain: Float) {
        guard index >= 0 && index < bands.count else { return }
        let clamped = max(-12.0, min(12.0, gain))
        bands[index].gain = clamped
        eqNode.bands[index].gain = clamped
    }

    /// Applies one of the standard EQ presets.
    func applyPreset(_ preset: EQPreset) {
        let presetGains = preset.gains
        for index in 0..<min(bands.count, presetGains.count) {
            let gain = presetGains[index]
            bands[index].gain = gain
            eqNode.bands[index].gain = gain
        }
    }

    /// Resets all bands to 0 dB.
    func resetToFlat() {
        selectedPreset = .flat
    }
}
