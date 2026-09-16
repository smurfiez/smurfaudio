import SwiftUI

/// Inline expandable equalizer drawer embedded directly within a row.
struct InlineFXDrawerView: View {
    @ObservedObject var eq: AudioUnitHosting
    var title: String = "Equalizer"
    var pan: Binding<Float>? = nil
    var isMono: Binding<Bool>? = nil
    var boostGain: Binding<Float>? = nil

    private let greenColor = Color(red: 0.17, green: 0.76, blue: 0.41)

    var body: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal, 4)

            // Header Controls
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 11))
                        .foregroundStyle(greenColor)

                    Text("\(title) (10-Band)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(eq.isBypassed ? "Bypassed" : "Active")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(eq.isBypassed ? Color.gray.opacity(0.15) : Color.green.opacity(0.15))
                        .foregroundStyle(eq.isBypassed ? Color.secondary : Color.green)
                        .clipShape(Capsule())
                }

                Spacer()

                // Preset picker
                Picker("", selection: $eq.selectedPreset) {
                    ForEach(EQPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)

                // Bypass switch
                Toggle("Bypass", isOn: $eq.isBypassed)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            .padding(.horizontal, 8)

            // 10-Band Horizontal Slider Bar Grid
            HStack(spacing: 6) {
                ForEach(eq.bands) { band in
                    InlineBandFader(band: band, isBypassed: eq.isBypassed) { newGain in
                        eq.setGain(forBand: band.id, gain: newGain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)

            // Dynamics & Stereo Controls Tray
            if pan != nil || isMono != nil || boostGain != nil {
                Divider()
                    .padding(.horizontal, 6)

                HStack(spacing: 12) {
                    if let panBinding = pan {
                        HStack(spacing: 5) {
                            Text("Balance")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("L")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            Slider(value: panBinding, in: -1.0...1.0)
                                .frame(width: 75)
                                .tint(greenColor)
                            Text("R")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            if panBinding.wrappedValue != 0.0 {
                                Button("Center") {
                                    panBinding.wrappedValue = 0.0
                                }
                                .font(.system(size: 8, weight: .medium))
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Spacer()

                    if let monoBinding = isMono {
                        Button {
                            monoBinding.wrappedValue.toggle()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: monoBinding.wrappedValue ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 8))
                                Text("Mono")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(monoBinding.wrappedValue ? greenColor.opacity(0.18) : Color.primary.opacity(0.06))
                            .foregroundStyle(monoBinding.wrappedValue ? greenColor : Color.secondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Downmix stereo audio to mono")
                    }

                    if let boostBinding = boostGain {
                        Menu {
                            Button("+6 dB (2x Volume)") {
                                boostBinding.wrappedValue = 6.0
                            }
                            Button("+12 dB (4x Volume)") {
                                boostBinding.wrappedValue = 12.0
                            }
                        } label: {
                            Text(String(format: "+%.0f dB Boost", boostBinding.wrappedValue))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(greenColor)
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
        .padding(.horizontal, 8)
    }
}

/// Mini vertical fader for an individual EQ band inside the inline drawer.
struct InlineBandFader: View {
    let band: EQBandInfo
    var isBypassed: Bool
    var onChange: (Float) -> Void

    private let greenColor = Color(red: 0.17, green: 0.76, blue: 0.41)

    var body: some View {
        VStack(spacing: 3) {
            // Current Gain dB
            Text(String(format: "%+.0f", band.gain))
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(isBypassed ? Color.secondary : (band.gain != 0 ? greenColor : Color.secondary))

            // Vertical slider track
            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width
                // normalized: -12 dB -> 0.0, +12 dB -> 1.0, 0 dB -> 0.5
                let norm = CGFloat((band.gain + 12.0) / 24.0)
                let clampedNorm = max(0, min(1, norm))
                let thumbY = height * (1.0 - clampedNorm)

                ZStack(alignment: .top) {
                    // Center zero mark
                    Rectangle()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: width, height: 1)
                        .offset(y: height * 0.5)

                    // Vertical groove
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 3, height: height)

                    // Thumb
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isBypassed ? Color.gray : Color.white)
                        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                        .frame(width: 14, height: 7)
                        .offset(x: -7 + width / 2, y: max(0, min(height - 7, thumbY - 3.5)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard !isBypassed else { return }
                            let clampedY = max(0, min(height, gesture.location.y))
                            let invertedNorm = 1.0 - (clampedY / height)
                            let newGain = -12.0 + Float(invertedNorm) * 24.0
                            onChange(round(newGain * 2) / 2) // Snap to 0.5 dB
                        }
                )
            }
            .frame(height: 52)

            // Frequency Label
            Text(band.displayFrequency)
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
