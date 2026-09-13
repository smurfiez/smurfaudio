import AppKit
import SwiftUI

/// Manages application-level lifecycle and background services.
final class AppDelegate: NSObject, NSApplicationDelegate {

    weak var audioState: AudioState?
    var controlWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TogglePinWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.toggleControlWindow()
        }
    }

    func toggleControlWindow() {
        if let window = controlWindow {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }

        guard let state = audioState else { return }

        let contentView = PopoverContentView(audioState: state)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "SmurfAudio"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.controlWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        audioState?.cleanup()
    }
}

