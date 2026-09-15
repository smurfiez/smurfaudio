import SwiftUI
import CoreAudio

/// SoundSource-style device selector capsule button with icon, label, and double chevron.
struct DevicePickerMenu: View {
    let currentDeviceName: String
    let currentSymbol: String
    let availableDevices: [AudioDevice]
    var onSelectDevice: (AudioDevice) -> Void
    var onSelectDefault: (() -> Void)? = nil
    var isRedirect: Bool = false

    var body: some View {
        Menu {
            if let onSelectDefault {
                Button {
                    onSelectDefault()
                } label: {
                    HStack {
                        Label("System Default", systemImage: "arrow.up")
                        if isRedirect && currentDeviceName == "System Default" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Divider()
            }

            ForEach(availableDevices) { device in
                Button {
                    onSelectDevice(device)
                } label: {
                    HStack {
                        Label(device.name, systemImage: device.systemSymbol)
                        if device.name == currentDeviceName {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: currentSymbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)

                Text(currentDeviceName)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                Spacer(minLength: 2)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: 175)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                    )
            )
        }
        .menuStyle(.borderlessButton)
    }
}
