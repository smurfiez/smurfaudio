import Foundation
import Accelerate
import AVFoundation
import CoreMedia

/// Computes real-time RMS and peak audio levels from PCM audio buffers using Accelerate `vDSP`.
final class AudioLevelMeter {

    // MARK: - State

    private var smoothedLevel: Float = 0.0
    private let decayFactor: Float = 0.85
    private let minDB: Float = -50.0 // Noise floor threshold

    // MARK: - Meter Calculation

    /// Processes an `AVAudioPCMBuffer` and returns a normalized audio level between 0.0 and 1.0.
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return smoothedLevel * decayFactor }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return smoothedLevel * decayFactor }

        var maxRMS: Float = 0.0

        for ch in 0..<channelCount {
            var channelRMS: Float = 0.0
            vDSP_rmsqv(channelData[ch], 1, &channelRMS, vDSP_Length(frameLength))
            if channelRMS > maxRMS {
                maxRMS = channelRMS
            }
        }

        return updateSmoothedLevel(rms: maxRMS)
    }

    /// Processes a `CMSampleBuffer` directly to calculate audio level.
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Float {
        guard sampleBuffer.isValid,
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return smoothedLevel * decayFactor
        }

        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let rawData = dataPointer, totalLength > 0 else {
            return smoothedLevel * decayFactor
        }

        let floatCount = totalLength / MemoryLayout<Float>.size
        guard floatCount > 0 else { return smoothedLevel * decayFactor }

        let floatPointer = UnsafeRawPointer(rawData).bindMemory(to: Float.self, capacity: floatCount)
        var rms: Float = 0.0
        vDSP_rmsqv(floatPointer, 1, &rms, vDSP_Length(floatCount))

        return updateSmoothedLevel(rms: rms)
    }

    /// Normalizes raw RMS to a decibel-scaled 0.0...1.0 range with fast attack and smooth decay.
    private func updateSmoothedLevel(rms: Float) -> Float {
        guard rms > 0.00001 else {
            smoothedLevel = max(0.0, smoothedLevel * decayFactor)
            return smoothedLevel
        }

        // Convert linear RMS to decibels: 20 * log10(rms)
        let db = 20.0 * log10f(rms)

        // Normalize: minDB (-50 dB) -> 0.0, 0 dB -> 1.0
        let normalized = max(0.0, min(1.0, (db - minDB) / (-minDB)))

        // Fast attack, smooth decay
        if normalized > smoothedLevel {
            smoothedLevel = normalized
        } else {
            smoothedLevel = smoothedLevel * decayFactor + normalized * (1.0 - decayFactor)
        }

        if smoothedLevel < 0.01 {
            smoothedLevel = 0.0
        }

        return smoothedLevel
    }

    /// Resets the meter to silence.
    func reset() {
        smoothedLevel = 0.0
    }
}
