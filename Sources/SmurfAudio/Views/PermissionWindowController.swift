import AppKit
import SwiftUI

/// Controls the lifecycle of the standalone modal/utility window requesting TCC permissions.
final class PermissionWindowController: NSObject, NSWindowDelegate {

    static let shared = PermissionWindowController()

    private var window: NSWindow?
    private weak var permissionManager: PermissionManager?

    private override init() {
        super.init()
    }

    /// Displays the permission request window, bringing it to the foreground.
    func show(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager

        if let existingWindow = window {
            if !existingWindow.isVisible {
                existingWindow.center()
                existingWindow.makeKeyAndOrderFront(nil)
            } else {
                existingWindow.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = PermissionRequestView(
            permissionManager: permissionManager,
            onClose: { [weak self] in
                self?.close()
            }
        )

        let hostingController = NSHostingController(rootView: contentView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 490),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "SmurfAudio - Permission Required"
        newWindow.contentViewController = hostingController
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.center()
        newWindow.delegate = self

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the permission window.
    func close() {
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        permissionManager?.stopPolling()
    }
}
