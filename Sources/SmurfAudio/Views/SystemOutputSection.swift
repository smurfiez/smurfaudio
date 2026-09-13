import SwiftUI

/// System audio output section: device picker, volume slider, and routing toggle.
struct SystemOutputSection: View {
    @ObservedObject var audioState: AudioState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "Output", systemSymbol: "speaker.wave.2.fill", tint: .blue)
                Spacer()

                // Routing toggle (Active when BlackHole is installed)
                if audioState.isBlackHoleInstalled {
                    Toggle(isOn: routingToggleBinding) {
                        Text(audioState.isRoutingActive ? "Routing Active" : "Bypass")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(audioState.isRoutingActive ? .green : .secondary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .padding(.trailing, 16)
                }
            }

            // Output destination picker
            Picker("Output Device", selection: outputDeviceBinding) {
                ForEach(selectableOutputDevices) { device in
                    Label(device.name, systemImage: device.systemSymbol)
                        .tag(Optional(device.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .padding(.horizontal, 16)

            // Volume slider & EQ button
            HStack(spacing: 8) {
                VolumeSlider(
                    volume: $audioState.systemOutputVolume,
                    tint: audioState.isMasterMuted ? .gray : .blue,
                    iconName: outputVolumeIcon
                )

                Button {
                    audioState.isShowingEQ.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                        .foregroundStyle(audioState.eq.isBypassed ? .secondary : Color.blue)
                        .padding(4)
                        .background(audioState.eq.isBypassed ? Color.clear : Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("10-Band Equalizer")
                .popover(isPresented: $audioState.isShowingEQ, arrowEdge: .trailing) {
                    EQControlView(eq: audioState.eq) {
                        audioState.isShowingEQ = false
                    }
                }
            }
            .padding(.horizontal, 16)

            // Status / Driver status notice
            if !audioState.isBlackHoleInstalled {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                    Text("BlackHole driver not active in CoreAudio.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            } else if let error = audioState.routingError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Filtered Devices

    /// Excludes virtual BlackHole loopbacks from the user-facing destination list
    private var selectableOutputDevices: [AudioDevice] {
        audioState.outputDevices.filter { !$0.isBlackHole }
    }

    // MARK: - Bindings

    private var routingToggleBinding: Binding<Bool> {
        Binding(
            get: { audioState.isRoutingActive },
            set: { _ in audioState.toggleGlobalRouting() }
        )
    }

    private var outputDeviceBinding: Binding<String?> {
        Binding(
            get: {
                if audioState.isRoutingActive {
                    return audioState.targetOutputDevice?.id
                } else {
                    return audioState.defaultOutputDevice?.id
                }
            },
            set: { newID in
                if let id = newID,
                   let device = audioState.outputDevices.first(where: { $0.id == id }) {
                    audioState.selectOutputDevice(device)
                }
            }
        )
    }

    private var outputVolumeIcon: String {
        if audioState.isMasterMuted || audioState.systemOutputVolume == 0 {
            return "speaker.slash.fill"
        }
        switch audioState.systemOutputVolume {
        case ..<0.33:
            return "speaker.wave.1.fill"
        case ..<0.66:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }
}
