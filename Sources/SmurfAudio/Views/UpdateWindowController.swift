import AppKit
import SwiftUI

/// Controls the lifecycle of the standalone update window.
public final class UpdateWindowController: NSObject, NSWindowDelegate {

    public static let shared = UpdateWindowController()

    private var window: NSWindow?
    private weak var updateManager: UpdateManager?

    private override init() {
        super.init()
    }

    /// Displays the software update window, bringing it to the foreground.
    public func show(updateManager: UpdateManager) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.show(updateManager: updateManager)
            }
            return
        }

        self.updateManager = updateManager

        if let existingWindow = window {
            if !existingWindow.isVisible {
                existingWindow.center()
            }
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = UpdateView(
            updateManager: updateManager,
            onClose: { [weak self] in
                self?.close()
            }
        )

        let hostingController = NSHostingController(rootView: contentView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "Software Update"
        newWindow.contentViewController = hostingController
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.center()
        newWindow.delegate = self

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the update window.
    public func close() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.close()
            }
            return
        }
        window?.orderOut(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        // Window closed by user
    }
}
