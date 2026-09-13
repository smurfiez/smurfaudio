import SwiftUI

/// Parametric 10-band equalizer view with preset selection and gain faders.
struct EQControlView: View {
    @ObservedObject var eq: AudioUnitHosting
    var title: String = "Master Equalizer"
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(eq.isBypassed ? "Bypassed" : "Active")
                        .font(.system(size: 10))
                        .foregroundStyle(eq.isBypassed ? Color.secondary : Color.green)
                }

                Spacer()

                // Presets menu
                Picker("Preset", selection: $eq.selectedPreset) {
                    ForEach(EQPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)

                // Bypass toggle
                Toggle(isOn: $eq.isBypassed) {
                    Text("Bypass")
                        .font(.system(size: 11))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                if let onClose {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            // 10-Band Graphic Fader Section
            HStack(spacing: 8) {
                ForEach(eq.bands) { band in
                    EQBandFader(
                        band: band,
                        isBypassed: eq.isBypassed,
                        onGainChange: { newGain in
                            eq.setGain(forBand: band.id, gain: newGain)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Footer
            HStack {
                Button("Reset to Flat") {
                    eq.resetToFlat()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

                Spacer()

                Text("±12 dB range")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Single Frequency Band Fader

private struct EQBandFader: View {
    let band: EQBandInfo
    let isBypassed: Bool
    let onGainChange: (Float) -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Decibel text readout
            Text(gainText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(isBypassed ? .secondary : gainColor)
                .frame(height: 12)

            // Vertical fader slider
            Slider(
                value: Binding(
                    get: { Double(band.gain) },
                    set: { onGainChange(Float($0)) }
                ),
                in: -12...12
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 100, height: 16)
            .padding(.vertical, 40)
            .disabled(isBypassed)

            // Frequency label
            Text(band.displayFrequency)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var gainText: String {
        if band.gain > 0 {
            return String(format: "+%.1f", band.gain)
        } else {
            return String(format: "%.1f", band.gain)
        }
    }

    private var gainColor: Color {
        if band.gain > 0 {
            return .blue
        } else if band.gain < 0 {
            return .orange
        } else {
            return .secondary
        }
    }
}
