import Foundation
import CoreGraphics
import AppKit

/// Manages macOS system TCC (Transparency, Consent, and Control) permissions,
/// specifically Screen & System Audio Recording (ScreenCaptureKit) and Accessibility.
final class PermissionManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var hasScreenCapturePermission: Bool = false
    @Published private(set) var isPolling: Bool = false

    // MARK: - Callbacks

    var onPermissionGranted: (() -> Void)?

    // MARK: - Private

    private var pollTimer: Timer?

    // MARK: - Initialization

    init() {
        self.hasScreenCapturePermission = checkScreenCapturePermission()
    }

    deinit {
        stopPolling()
    }

    // MARK: - Screen Recording Permission

    /// Checks whether Screen & System Audio Recording permission is currently granted without prompting.
    @discardableResult
    func checkScreenCapturePermission() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        if granted != self.hasScreenCapturePermission {
            DispatchQueue.main.async {
                self.hasScreenCapturePermission = granted
                if granted {
                    self.onPermissionGranted?()
                }
            }
        }
        return granted
    }

    /// Explicitly prompts the user for Screen & System Audio Recording permission via macOS system dialog.
    /// If permission has already been declined or denied in the past, the system prompt will not reappear;
    /// this method returns false.
    @discardableResult
    func requestScreenCaptureAccess() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        DispatchQueue.main.async {
            self.hasScreenCapturePermission = granted
            if granted {
                self.onPermissionGranted?()
            }
        }
        return granted
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Screen & System Audio Recording.
    func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Accessibility.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Polling

    /// Starts periodic polling to detect when the user enables permission in System Settings.
    func startPolling(interval: TimeInterval = 1.0) {
        guard pollTimer == nil else { return }
        isPolling = true

        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            if self.checkScreenCapturePermission() {
                print("[PermissionManager] Screen Recording permission detected!")
                self.stopPolling()
            }
        }
    }

    /// Stops polling.
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        isPolling = false
    }
}
