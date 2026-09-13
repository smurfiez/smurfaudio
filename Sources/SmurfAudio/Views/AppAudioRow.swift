import SwiftUI
import AppKit
import CoreAudio

/// A row representing an application with real-time volume, mute, EQ, and separate speaker destination controls.
struct AppAudioRow: View {
    @ObservedObject var app: AppAudioSource
    let outputDevices: [AudioDevice]
    let onToggleCapture: () -> Void
    let onSelectOutputDevice: (AudioDeviceID?) -> Void

    @State private var isShowingEQ: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: icon, name, speaker destination picker, and action buttons
            HStack(spacing: 8) {
                AppIconView(icon: app.icon)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    if app.isCapturing {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Isolated")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Output Speaker Destination Menu
                Menu {
                    Button {
                        onSelectOutputDevice(nil as AudioDeviceID?)
                    } label: {
                        HStack {
                            Text("System Default")
                            if app.selectedOutputDeviceID == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    ForEach(selectableOutputDevices) { device in
                        Button {
                            onSelectOutputDevice(device.audioDeviceID)
                        } label: {
                            HStack {
                                Label(device.name, systemImage: device.systemSymbol)
                                if app.selectedOutputDeviceID == device.audioDeviceID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: selectedDeviceSymbol)
                        Text(selectedDeviceName)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7))
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(app.selectedOutputDeviceID != nil ? Color.blue : Color.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(app.selectedOutputDeviceID != nil ? Color.blue.opacity(0.12) : Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .menuStyle(.borderlessButton)
                .help("Select output speaker for \(app.name)")

                // Isolate button
                Button {
                    onToggleCapture()
                } label: {
                    Text(app.isCapturing ? "Active" : "Isolate")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(app.isCapturing ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                        .foregroundStyle(app.isCapturing ? .green : .secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(app.isCapturing ? "Stop isolating audio" : "Isolate and route audio with ScreenCaptureKit")

                // Mute toggle
                Button {
                    app.isMuted.toggle()
                } label: {
                    Image(systemName: app.isMuted
                          ? "speaker.slash.fill"
                          : "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(app.isMuted ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help(app.isMuted ? "Unmute \(app.name)" : "Mute \(app.name)")

                // EQ button
                Button {
                    isShowingEQ.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(app.eq.isBypassed ? .secondary : Color.purple)
                        .padding(2)
                        .background(app.eq.isBypassed ? Color.clear : Color.purple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .help("Equalizer for \(app.name)")
                .popover(isPresented: $isShowingEQ, arrowEdge: .trailing) {
                    EQControlView(eq: app.eq, title: "\(app.name) Equalizer") {
                        isShowingEQ = false
                    }
                }
            }

            // Volume slider
            HStack(spacing: 8) {
                Slider(value: $app.volume, in: 0...1)
                    .tint(app.isMuted ? .gray : .accentColor)
                    .disabled(app.isMuted)

                Text("\(Int(app.volume * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }

            // Capture error if any
            if let error = app.captureError {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error.contains("declined") || error.contains("permission")
                             ? "Permission needed: click to open Privacy Settings"
                             : error)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Device Display Helpers

    private var selectableOutputDevices: [AudioDevice] {
        outputDevices.filter { !$0.isBlackHole }
    }

    private var selectedDevice: AudioDevice? {
        guard let id = app.selectedOutputDeviceID else { return nil }
        return outputDevices.first { $0.audioDeviceID == id }
    }

    private var selectedDeviceName: String {
        selectedDevice?.name ?? "Default"
    }

    private var selectedDeviceSymbol: String {
        selectedDevice?.systemSymbol ?? "speaker.wave.2"
    }
}

// MARK: - App Icon

/// Displays an app icon at 24×24, falling back to a generic SF Symbol.
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
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
