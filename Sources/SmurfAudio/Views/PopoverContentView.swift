import SwiftUI

// MARK: - Root Popover View

/// The main content view hosted inside the menu bar popover.
/// Organized into three sections: Output, Input, and Applications.
struct PopoverContentView: View {
    @ObservedObject var audioState: AudioState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SystemOutputSection(audioState: audioState)

                SectionDivider()

                SystemInputSection(audioState: audioState)

                SectionDivider()

                ApplicationsSection(audioState: audioState)

                SectionDivider()

                // Footer
                HStack(spacing: 8) {
                    Text("SmurfAudio")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if !audioState.mediaKeyInterceptor.hasAccessibilityPermission {
                        Button {
                            audioState.mediaKeyInterceptor.openAccessibilitySettings()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "keyboard")
                                Text("Enable Volume Keys")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Click to grant Accessibility permission in System Settings for volume key control")
                    }

                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("TogglePinWindow"), object: nil)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "pip.enter")
                            Text("Float Window")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open as a standalone floating window that stays on your screen")

                    Button("Quit") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .padding(.vertical, 8)
        }
        .frame(width: 340, height: 500)
    }
}

// MARK: - Applications Section

struct ApplicationsSection: View {
    @ObservedObject var audioState: AudioState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SectionHeader(
                    title: "Applications",
                    systemSymbol: "square.grid.2x2.fill",
                    tint: .purple
                )

                Spacer()

                Button {
                    Task {
                        await audioState.refreshRunningApps()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(audioState.isScanningApps ? 360 : 0))
                        .animation(audioState.isScanningApps ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: audioState.isScanningApps)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .help("Refresh running applications")
            }

            if audioState.runningApps.isEmpty {
                Text("No user applications detected.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                ForEach(audioState.runningApps) { app in
                    AppAudioRow(
                        app: app,
                        outputDevices: audioState.outputDevices,
                        onToggleCapture: {
                            audioState.toggleCapture(for: app)
                        },
                        onSelectOutputDevice: { deviceID in
                            audioState.selectAppOutputDevice(app: app, deviceID: deviceID)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Shared Components

/// Section label with a tinted SF Symbol and uppercase title.
struct SectionHeader: View {
    let title: String
    let systemSymbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemSymbol)
                .foregroundStyle(tint)
                .font(.caption)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

/// Horizontal divider with consistent insets between sections.
struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 12)
    }
}

/// Reusable horizontal volume slider with an icon and percentage label.
struct VolumeSlider: View {
    @Binding var volume: Float
    let tint: Color
    let iconName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .frame(width: 16)
                .foregroundStyle(.secondary)
                .font(.caption)

            Slider(value: $volume, in: 0...1)
                .tint(tint)

            Text("\(Int(volume * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
