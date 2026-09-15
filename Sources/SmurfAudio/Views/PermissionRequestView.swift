import SwiftUI
import AppKit

/// Dedicated dialog window view explaining why Screen & Audio Recording permission is required
/// and providing direct actions to configure it in macOS System Settings.
struct PermissionRequestView: View {
    @ObservedObject var permissionManager: PermissionManager
    var onClose: (() -> Void)?

    private let greenColor = Color(red: 0.17, green: 0.76, blue: 0.41)

    var body: some View {
        VStack(spacing: 20) {
            // Header with Icon
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(permissionManager.hasScreenCapturePermission ? greenColor.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: permissionManager.hasScreenCapturePermission ? "checkmark.shield.fill" : "display.trianglebadge.exclamationmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(permissionManager.hasScreenCapturePermission ? greenColor : Color.orange)
                }

                Text("Permission Required")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Screen & System Audio Recording")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Informational Description
            Text("SmurfAudio captures, routes, and mixes audio from individual running applications. On macOS, this requires **Screen & System Audio Recording** access.\n\nSmurfAudio only accesses application audio streams and never records, captures, or transmits your screen display.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 12)

            // Status Card & Steps
            VStack(alignment: .leading, spacing: 10) {
                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(permissionManager.hasScreenCapturePermission ? greenColor : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(permissionManager.hasScreenCapturePermission ? "Status: Permission Granted" : "Status: Permission Declined or Not Enabled")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(permissionManager.hasScreenCapturePermission ? greenColor : Color.orange)

                    Spacer()

                    if permissionManager.isPolling && !permissionManager.hasScreenCapturePermission {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // Instructions
                VStack(alignment: .leading, spacing: 6) {
                    instructionStep(number: "1", text: "Click the **Open System Settings** button below.")
                    instructionStep(number: "2", text: "Locate **SmurfAudio** under Screen & System Audio Recording and turn the switch **ON**.")
                    instructionStep(number: "3", text: "If macOS prompts you to Quit & Reopen, do so to apply changes.")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 8)

            Spacer(minLength: 4)

            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    onClose?()
                } label: {
                    Text(permissionManager.hasScreenCapturePermission ? "Done" : "Dismiss")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button {
                    _ = permissionManager.checkScreenCapturePermission()
                } label: {
                    Label("Check Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    permissionManager.openScreenCaptureSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text("Open System Settings")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(greenColor)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 8)
        }
        .padding(20)
        .frame(width: 480, height: 460)
        .onAppear {
            permissionManager.checkScreenCapturePermission()
            permissionManager.startPolling()
        }
        .onDisappear {
            permissionManager.stopPolling()
        }
    }

    private func instructionStep(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.secondary))

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
