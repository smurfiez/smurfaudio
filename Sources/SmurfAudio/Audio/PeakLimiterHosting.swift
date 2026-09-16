import Foundation
import AVFoundation
import AudioToolbox

/// Hosts and controls Apple's native `kAudioUnitSubType_PeakLimiter` Audio Unit.
///
/// Used for distortion-free volume overdrive (Boost mode) and dynamic peak protection.
final class PeakLimiterHosting: ObservableObject {

    // MARK: - Published Properties

    /// Whether volume overdrive boost is active.
    @Published var isBoostActive: Bool = false {
        didSet {
            updateLimiter()
        }
    }

    /// Pre-gain in decibels applied before the peak limiter threshold (e.g., +6 dB or +12 dB).
    @Published var boostGain: Float = 6.0 {
        didSet {
            updateLimiter()
        }
    }

    // MARK: - Underlying Audio Unit

    /// The AVAudioUnitEffect wrapping Apple's peak limiter.
    let limiterNode: AVAudioUnitEffect

    // MARK: - Initialization

    init() {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        self.limiterNode = AVAudioUnitEffect(audioComponentDescription: desc)

        // Default attack time: 0.005s, decay time: 0.020s
        AudioUnitSetParameter(
            limiterNode.audioUnit,
            AudioUnitParameterID(kLimiterParam_AttackTime),
            kAudioUnitScope_Global,
            0,
            0.005,
            0
        )
        AudioUnitSetParameter(
            limiterNode.audioUnit,
            AudioUnitParameterID(kLimiterParam_DecayTime),
            kAudioUnitScope_Global,
            0,
            0.020,
            0
        )

        // Initial state: bypassed with 0 dB gain
        limiterNode.bypass = true
        setPreGain(0.0)
    }

    // MARK: - Configuration

    /// Updates limiter bypass and pre-gain based on current boost state.
    private func updateLimiter() {
        if isBoostActive {
            limiterNode.bypass = false
            setPreGain(boostGain)
        } else {
            limiterNode.bypass = true
            setPreGain(0.0)
        }
    }

    /// Sets the digital pre-gain in decibels (-40 dB to +40 dB).
    func setPreGain(_ gainInDB: Float) {
        let clamped = max(-40.0, min(40.0, gainInDB))
        AudioUnitSetParameter(
            limiterNode.audioUnit,
            AudioUnitParameterID(kLimiterParam_PreGain),
            kAudioUnitScope_Global,
            0,
            clamped,
            0
        )
    }
}
