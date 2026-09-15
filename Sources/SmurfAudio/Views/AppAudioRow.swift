import SwiftUI
import AppKit
import CoreAudio

/// Redesigned row for an application with Star favorite, level meter, slider, boost, device picker, and inline FX.
struct AppAudioRow: View {
    @ObservedObject var app: AppAudioSource
    @ObservedObject var audioState: AudioState
    let outputDevices: [AudioDevice]
    let onToggleCapture: () -> Void
    let onSelectOutputDevice: (AudioDeviceID?) -> Void

    private let greenColor = Color(red: 0.17, green: 0.76, blue: 0.41)

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Favorite Star Toggle
                Button {
                    audioState.toggleFavorite(for: app.bundleIdentifier)
                } label: {
                    Image(systemName: app.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(app.isFavorite ? greenColor : Color.secondary.opacity(0.6))
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
                .help(app.isFavorite ? "Remove from favorites" : "Add to favorites")

                // Level meter pill
                LevelMeterPill(
                    isActive: app.isCapturing && !app.isMuted && app.volume > 0,
                    level: CGFloat(app.volume)
                )

                // App Icon
                AppIconView(icon: app.icon)

                // App Name
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 75, alignment: .leading)

                Spacer(minLength: 4)

                // Mute Button
                Button {
                    app.isMuted.toggle()
                } label: {
                    Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(app.isMuted ? .red : .primary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
                .help(app.isMuted ? "Unmute \(app.name)" : "Mute \(app.name)")

                // Volume Slider + Percentage
                SoundSourceSlider(
                    value: $app.volume,
                    isMuted: app.isMuted,
                    isBoosted: app.isBoostActive
                )
                .frame(width: 146)

                // Boost Button
                Button {
                    app.isBoostActive.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(app.isBoostActive ? greenColor.opacity(0.18) : Color.primary.opacity(0.06))
                            .frame(width: 22, height: 22)
                        VStack(spacing: -3) {
                            Image(systemName: "chevron.compact.up")
                            Image(systemName: "chevron.compact.up")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(app.isBoostActive ? greenColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 32)
                .help("Overdrive / Volume Boost")

                // Redirect Audio To Picker
                DevicePickerMenu(
                    currentDeviceName: selectedDeviceName,
                    currentSymbol: selectedDeviceSymbol,
                    availableDevices: selectableOutputDevices,
                    onSelectDevice: { device in
                        if !app.isCapturing {
                            onToggleCapture()
                        }
                        onSelectOutputDevice(device.audioDeviceID)
                    },
                    onSelectDefault: {
                        onSelectOutputDevice(nil)
                    },
                    isRedirect: true
                )

                // FX Expand Button
                Button {
                    audioState.toggleFX(for: app.id.uuidString)
                } label: {
                    Image(systemName: isFXExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFXExpanded ? greenColor : .secondary)
                        .frame(width: 20, height: 20)
                        .background(isFXExpanded ? greenColor.opacity(0.15) : Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(width: 24)
                .help("Toggle Equalizer for \(app.name)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            // Inline FX Equalizer Drawer
            if isFXExpanded {
                InlineFXDrawerView(eq: app.eq, title: "\(app.name) Equalizer")
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Capture error if any
            if let error = app.captureError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 2)
            }
        }
    }

    // MARK: - Helpers

    private var isFXExpanded: Bool {
        audioState.expandedFXID == app.id.uuidString
    }

    private var selectableOutputDevices: [AudioDevice] {
        outputDevices.filter { !$0.isBlackHole }
    }

    private var selectedDevice: AudioDevice? {
        guard let id = app.selectedOutputDeviceID else { return nil }
        return outputDevices.first { $0.audioDeviceID == id }
    }

    private var selectedDeviceName: String {
        selectedDevice?.name ?? "No Redirect"
    }

    private var selectedDeviceSymbol: String {
        if selectedDevice == nil {
            return "arrow.up"
        }
        return selectedDevice?.systemSymbol ?? "speaker.wave.2"
    }
}

// MARK: - App Icon

/// Displays an app icon at 20×20 with rounded corners.
struct AppIconView: View {
    let icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
