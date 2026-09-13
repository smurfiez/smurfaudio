import SwiftUI

/// System audio input section: live device picker and volume slider.
struct SystemInputSection: View {
    @ObservedObject var audioState: AudioState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Input", systemSymbol: "mic.fill", tint: .green)

            // Device picker — reads/writes the system default input device
            Picker("Input Device", selection: inputDeviceBinding) {
                ForEach(audioState.inputDevices) { device in
                    Label(device.name, systemImage: device.systemSymbol)
                        .tag(Optional(device.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .padding(.horizontal, 16)

            // Volume slider
            VolumeSlider(
                volume: $audioState.systemInputVolume,
                tint: .green,
                iconName: audioState.systemInputVolume > 0 ? "mic.fill" : "mic.slash.fill"
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Bindings

    /// Two-way binding: reads the current system default input device,
    /// writes to CoreAudio when the user picks a different one.
    private var inputDeviceBinding: Binding<String?> {
        Binding(
            get: { audioState.defaultInputDevice?.id },
            set: { newID in
                if let id = newID,
                   let device = audioState.inputDevices.first(where: { $0.id == id }) {
                    audioState.selectInputDevice(device)
                }
            }
        )
    }
}
