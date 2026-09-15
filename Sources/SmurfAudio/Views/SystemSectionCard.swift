import SwiftUI
import CoreAudio

/// Card container for System audio channels (Output, Input, and Sound Effects).
struct SystemSectionCard: View {
    @ObservedObject var audioState: AudioState
    @State private var isExpanded: Bool = true

    // Vibrant green for boost and active controls
    private let greenColor = Color(red: 0.17, green: 0.76, blue: 0.41)

    var body: some View {
        VStack(spacing: 0) {
            // Header Row: [v] System, Volume, Boost, Device, FX
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("System")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                // Column Headers
                Text("Volume")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 170, alignment: .center)

                Text("Boost")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .center)

                Text("Device")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 175, alignment: .center)

                Text("FX")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 8)

                VStack(spacing: 2) {
                    // 1. Output Row
                    outputRow

                    if audioState.expandedFXID == "output" {
                        InlineFXDrawerView(eq: audioState.eq, title: "Master Output")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 2. Input Row
                    inputRow

                    if audioState.expandedFXID == "input" {
                        InlineFXDrawerView(eq: audioState.eq, title: "Microphone Input")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 3. Sound Effects Row
                    soundEffectsRow

                    if audioState.expandedFXID == "sfx" {
                        InlineFXDrawerView(eq: audioState.eq, title: "Sound Effects")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        )
        .padding(.horizontal, 12)
    }

    // MARK: - Output Row

    private var outputRow: some View {
        HStack(spacing: 8) {
            // Level Pill
            LevelMeterPill(
                isActive: !audioState.isMasterMuted && audioState.systemOutputVolume > 0,
                level: CGFloat(audioState.systemOutputVolume)
            )

            // Icon box
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 22, height: 22)
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            // Label
            Text("Output")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 75, alignment: .leading)

            Spacer(minLength: 4)

            // Mute Button
            Button {
                audioState.isMasterMuted.toggle()
            } label: {
                Image(systemName: audioState.isMasterMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(audioState.isMasterMuted ? .red : .primary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            // Volume Slider + Percentage
            SoundSourceSlider(
                value: $audioState.systemOutputVolume,
                isMuted: audioState.isMasterMuted,
                isBoosted: audioState.isMasterBoostActive
            )
            .frame(width: 146)

            // Boost Button (Triple chevron stack)
            Button {
                audioState.isMasterBoostActive.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(audioState.isMasterBoostActive ? greenColor.opacity(0.18) : Color.primary.opacity(0.06))
                        .frame(width: 22, height: 22)
                    VStack(spacing: -3) {
                        Image(systemName: "chevron.compact.up")
                        Image(systemName: "chevron.compact.up")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(audioState.isMasterBoostActive ? greenColor : .secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 32)
            .help("Overdrive / Volume Boost")

            // Device Picker
            DevicePickerMenu(
                currentDeviceName: currentOutputName,
                currentSymbol: currentOutputSymbol,
                availableDevices: selectableOutputDevices,
                onSelectDevice: { device in
                    audioState.selectOutputDevice(device)
                }
            )

            // FX Button
            Button {
                audioState.toggleFX(for: "output")
            } label: {
                Image(systemName: audioState.expandedFXID == "output" ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(audioState.expandedFXID == "output" ? greenColor : .secondary)
                    .frame(width: 20, height: 20)
                    .background(audioState.expandedFXID == "output" ? greenColor.opacity(0.15) : Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 24)
            .help("Toggle Equalizer")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 8) {
            LevelMeterPill(
                isActive: !audioState.isInputMuted && audioState.systemInputVolume > 0,
                level: CGFloat(audioState.systemInputVolume)
            )

            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 22, height: 22)
                Image(systemName: "mic.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            Text("Input")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 75, alignment: .leading)

            Spacer(minLength: 4)

            Button {
                audioState.isInputMuted.toggle()
            } label: {
                Image(systemName: audioState.isInputMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(audioState.isInputMuted ? .red : .primary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            SoundSourceSlider(
                value: $audioState.systemInputVolume,
                isMuted: audioState.isInputMuted,
                isBoosted: audioState.isInputBoostActive
            )
            .frame(width: 146)

            Button {
                audioState.isInputBoostActive.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(audioState.isInputBoostActive ? greenColor.opacity(0.18) : Color.primary.opacity(0.06))
                        .frame(width: 22, height: 22)
                    VStack(spacing: -3) {
                        Image(systemName: "chevron.compact.up")
                        Image(systemName: "chevron.compact.up")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(audioState.isInputBoostActive ? greenColor : .secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 32)
            .help("Microphone Gain Boost")

            DevicePickerMenu(
                currentDeviceName: currentInputName,
                currentSymbol: currentInputSymbol,
                availableDevices: audioState.inputDevices,
                onSelectDevice: { device in
                    audioState.selectInputDevice(device)
                }
            )

            Button {
                audioState.toggleFX(for: "input")
            } label: {
                Image(systemName: audioState.expandedFXID == "input" ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(audioState.expandedFXID == "input" ? greenColor : .secondary)
                    .frame(width: 20, height: 20)
                    .background(audioState.expandedFXID == "input" ? greenColor.opacity(0.15) : Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 24)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: - Sound Effects Row

    private var soundEffectsRow: some View {
        HStack(spacing: 8) {
            LevelMeterPill(
                isActive: !audioState.isSoundEffectsMuted && audioState.soundEffectsVolume > 0,
                level: CGFloat(audioState.soundEffectsVolume)
            )

            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 22, height: 22)
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            Text("Sound Effects")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 75, alignment: .leading)

            Spacer(minLength: 4)

            Button {
                audioState.isSoundEffectsMuted.toggle()
            } label: {
                Image(systemName: audioState.isSoundEffectsMuted ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(audioState.isSoundEffectsMuted ? .red : .primary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            SoundSourceSlider(
                value: $audioState.soundEffectsVolume,
                isMuted: audioState.isSoundEffectsMuted,
                isBoosted: audioState.isSoundEffectsBoostActive
            )
            .frame(width: 146)

            Button {
                audioState.isSoundEffectsBoostActive.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(audioState.isSoundEffectsBoostActive ? greenColor.opacity(0.18) : Color.primary.opacity(0.06))
                        .frame(width: 22, height: 22)
                    VStack(spacing: -3) {
                        Image(systemName: "chevron.compact.up")
                        Image(systemName: "chevron.compact.up")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(audioState.isSoundEffectsBoostActive ? greenColor : .secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 32)
            .help("Sound Effects Boost")

            DevicePickerMenu(
                currentDeviceName: currentSFXName,
                currentSymbol: currentSFXSymbol,
                availableDevices: selectableOutputDevices,
                onSelectDevice: { device in
                    audioState.selectSystemOutputDevice(device)
                }
            )

            Button {
                audioState.toggleFX(for: "sfx")
            } label: {
                Image(systemName: audioState.expandedFXID == "sfx" ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(audioState.expandedFXID == "sfx" ? greenColor : .secondary)
                    .frame(width: 20, height: 20)
                    .background(audioState.expandedFXID == "sfx" ? greenColor.opacity(0.15) : Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 24)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var selectableOutputDevices: [AudioDevice] {
        audioState.outputDevices.filter { !$0.isBlackHole }
    }

    private var currentOutputName: String {
        if audioState.isRoutingActive {
            return audioState.targetOutputDevice?.name ?? "Speakers"
        }
        return audioState.defaultOutputDevice?.name ?? "Speakers"
    }

    private var currentOutputSymbol: String {
        if audioState.isRoutingActive {
            return audioState.targetOutputDevice?.systemSymbol ?? "speaker.wave.2"
        }
        return audioState.defaultOutputDevice?.systemSymbol ?? "speaker.wave.2"
    }

    private var currentInputName: String {
        audioState.defaultInputDevice?.name ?? "Microphone"
    }

    private var currentInputSymbol: String {
        audioState.defaultInputDevice?.systemSymbol ?? "mic.fill"
    }

    private var currentSFXName: String {
        audioState.defaultSystemOutputDevice?.name ?? currentOutputName
    }

    private var currentSFXSymbol: String {
        audioState.defaultSystemOutputDevice?.systemSymbol ?? "bell.fill"
    }
}
