import SwiftUI
import AppKit

/// Dedicated update dialog view displaying release details, release notes,
/// download progress, and installation actions.
public struct UpdateView: View {
    @ObservedObject var updateManager: UpdateManager
    var onClose: () -> Void

    private let greenColor = Color(red: 0.17, green: 0.76, blue: 0.41)

    public init(updateManager: UpdateManager, onClose: @escaping () -> Void) {
        self.updateManager = updateManager
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView

            Divider()

            // Main Content Area based on Status
            contentArea

            Divider()

            // Footer / Action Bar
            footerButtons
        }
        .padding(20)
        .frame(width: 520, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(greenColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(greenColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(headerTitle)
                    .font(.system(size: 16, weight: .bold))

                HStack(spacing: 8) {
                    Text("Installed: v\(updateManager.currentVersionString)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let rel = updateManager.latestRelease {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        Text("Latest: \(rel.tagName)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(greenColor)
                    }
                }
            }

            Spacer()
        }
    }

    private var headerTitle: String {
        switch updateManager.status {
        case .checking:
            return "Checking for Updates..."
        case .updateAvailable:
            return "A new version of SmurfAudio is available!"
        case .downloading:
            return "Downloading SmurfAudio Update..."
        case .readyToInstall:
            return "Update Ready to Install"
        case .upToDate:
            return "SmurfAudio is Up to Date"
        case .failed:
            return "Update Check Failed"
        case .idle:
            return "SmurfAudio Software Update"
        }
    }

    // MARK: - Content Area
    @ViewBuilder
    private var contentArea: some View {
        switch updateManager.status {
        case .checking:
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("Connecting to GitHub...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .upToDate:
            VStack(spacing: 14) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(greenColor)

                Text("You're using the latest version of SmurfAudio (v\(updateManager.currentVersionString)).")
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)

                if let date = updateManager.lastCheckDate {
                    Text("Last checked: \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let error):
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                Text("Unable to check for updates")
                    .font(.system(size: 13, weight: .bold))

                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .downloading(let progress, let written, let total):
            VStack(spacing: 16) {
                Spacer()

                VStack(spacing: 8) {
                    ProgressView(value: progress, total: 1.0)
                        .tint(greenColor)

                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if total > 0 {
                            Text(formatBytes(written, total: total))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Text("Downloading release asset from GitHub...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .readyToInstall:
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(greenColor)

                Text("Update package downloaded successfully.")
                    .font(.system(size: 13, weight: .bold))

                Text("Click \"Install & Relaunch\" to launch the installer package. SmurfAudio will guide you through updating.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .updateAvailable, .idle:
            if let release = updateManager.latestRelease {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(release.name ?? release.tagName)
                            .font(.system(size: 13, weight: .bold))

                        Spacer()

                        if let asset = release.bestAsset {
                            Text("(\(asset.name) • \(asset.formattedSize))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Release notes card
                    ScrollView(.vertical) {
                        Text(release.body ?? "No release notes provided.")
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Footer Buttons
    private var footerButtons: some View {
        HStack {
            // Auto-check toggle
            Toggle("Automatically check for updates", isOn: $updateManager.automaticallyChecksForUpdates)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))

            Spacer()

            switch updateManager.status {
            case .upToDate:
                Button("OK") {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)

            case .failed:
                Button("Close") {
                    onClose()
                }

                Button("Open GitHub") {
                    updateManager.openReleasePage()
                }

                Button("Retry") {
                    Task { await updateManager.checkForUpdates(silent: false) }
                }
                .keyboardShortcut(.defaultAction)

            case .downloading:
                Button("Cancel") {
                    updateManager.reset()
                    onClose()
                }

            case .readyToInstall:
                Button("Cancel") {
                    onClose()
                }

                Button("Install & Relaunch") {
                    updateManager.installAndRelaunch()
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(greenColor)
                .keyboardShortcut(.defaultAction)

            case .updateAvailable:
                Button("Skip Version") {
                    updateManager.skipCurrentVersion()
                }

                Button("Later") {
                    onClose()
                }

                Button("Download & Install") {
                    Task { await updateManager.downloadUpdate() }
                }
                .buttonStyle(.borderedProminent)
                .tint(greenColor)
                .keyboardShortcut(.defaultAction)

            case .checking, .idle:
                Button("Close") {
                    onClose()
                }
            }
        }
    }

    private func formatBytes(_ written: Int64, total: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: written)) of \(formatter.string(fromByteCount: total))"
    }
}
