import SwiftUI
import AppKit

// MARK: - Root Popover View

/// The redesigned SoundSource-style root view hosted inside the menu bar and floating window.
struct PopoverContentView: View {
    @ObservedObject var audioState: AudioState

    private let greenColor = Color(red: 0.17, green: 0.76, blue: 0.41)

    var body: some View {
        VStack(spacing: 10) {
            // Top Header Bar
            headerBar

            // Scrollable Cards Container
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // 1. System Card (Output, Input, Sound Effects)
                    SystemSectionCard(audioState: audioState)

                    // 2. Applications Card
                    applicationsCard
                }
                .padding(.vertical, 4)
            }

            // Bottom Toolbar (Add Favorite & Status)
            bottomToolbar
        }
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 580, height: 580)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            // Pin Window Button
            Button {
                audioState.toggleWindowPin()
            } label: {
                Image(systemName: audioState.isWindowPinned ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(audioState.isWindowPinned ? greenColor : .secondary)
                    .frame(width: 26, height: 26)
                    .background(audioState.isWindowPinned ? greenColor.opacity(0.15) : Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(audioState.isWindowPinned ? "Unpin Window" : "Pin Window on Top")

            // Float Window Button
            Button {
                NotificationCenter.default.post(name: NSNotification.Name("TogglePinWindow"), object: nil)
            } label: {
                Image(systemName: "pip.enter")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Open as floating standalone window")

            Spacer()

            // App Title
            Text("SmurfAudio")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            // Screen Recording Permission Warning (if needed)
            if !audioState.mediaKeyInterceptor.hasAccessibilityPermission {
                Button {
                    audioState.mediaKeyInterceptor.openAccessibilitySettings()
                } label: {
                    Image(systemName: "keyboard.badge.waveform")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                        .frame(width: 26, height: 26)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Accessibility permission needed for volume keys (Click to open settings)")
            }

            // Gear / Settings Menu
            Menu {
                Button {
                    Task { await audioState.refreshRunningApps() }
                } label: {
                    Label("Refresh Running Apps", systemImage: "arrow.clockwise")
                }

                Divider()

                if audioState.isBlackHoleInstalled {
                    Button {
                        audioState.toggleGlobalRouting()
                    } label: {
                        Label(
                            audioState.isRoutingActive ? "Routing: Active (Bypass)" : "Routing: Bypassed (Activate)",
                            systemImage: audioState.isRoutingActive ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }

                Button {
                    audioState.eq.resetToFlat()
                } label: {
                    Label("Reset Equalizer to Flat", systemImage: "slider.horizontal.below.rectangle")
                }

                Divider()

                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Screen & Audio Permissions...", systemImage: "hand.raised.fill")
                }

                Button {
                    audioState.mediaKeyInterceptor.openAccessibilitySettings()
                } label: {
                    Label("Accessibility Settings...", systemImage: "keyboard")
                }

                Divider()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit SmurfAudio", systemImage: "power")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(greenColor)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .help("Settings & Options")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Applications Card

    @State private var isAppsExpanded: Bool = true

    private var applicationsCard: some View {
        VStack(spacing: 0) {
            // Header Row: [v] Applications, Volume, Boost, Redirect Audio To, FX
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAppsExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isAppsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("Applications")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                // Column Headers aligned with row items
                Text("Volume")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 170, alignment: .center)

                Text("Boost")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .center)

                Text("Redirect Audio To")
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

            if isAppsExpanded {
                Divider()
                    .padding(.horizontal, 8)

                if audioState.runningApps.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("No active audio applications detected.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 4) {
                        ForEach(audioState.runningApps) { app in
                            AppAudioRow(
                                app: app,
                                audioState: audioState,
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
                    .padding(.vertical, 6)
                }
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

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            // Add Favorite Menu
            Menu {
                Text("Pin an application to favorites:")
                Divider()
                ForEach(audioState.runningApps) { app in
                    Button {
                        audioState.toggleFavorite(for: app.bundleIdentifier)
                    } label: {
                        HStack {
                            Text(app.name)
                            if app.isFavorite {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text("Add Favorite")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                        )
                )
            }
            .menuStyle(.borderlessButton)

            Spacer()

            if audioState.isRoutingActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(greenColor)
                        .frame(width: 6, height: 6)
                    Text("BlackHole Routing Active")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }
}
