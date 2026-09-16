import Foundation
import CoreGraphics
import AppKit

/// Intercepts physical keyboard volume keys (F11 / F12 / Mute) using a low-level `CGEvent` tap.
///
/// Enables "Super Volume Keys" for external monitors (HDMI, DisplayPort, Thunderbolt)
/// that macOS normally refuses to control.
final class MediaKeyInterceptor: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isListening: Bool = false
    @Published private(set) var hasAccessibilityPermission: Bool = false

    // MARK: - Event Tap State

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Callbacks

    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?
    var onMuteToggle: (() -> Void)?

    // MARK: - Initialization

    init() {
        checkPermission()
    }

    deinit {
        stop()
    }

    // MARK: - Permissions

    private var permissionPollTimer: Timer?

    /// Checks whether the user has granted Accessibility permission to SmurfAudio.
    @discardableResult
    func checkPermission() -> Bool {
        let granted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = granted
        }
        return granted
    }

    /// Triggers macOS System Settings prompt and opens Accessibility preferences.
    func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Periodically checks if the user granted permission in System Settings.
    func startPollingPermission() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self else { return }
            if self.checkPermission() {
                self.start()
                timer.invalidate()
                self.permissionPollTimer = nil
                print("[MediaKeyInterceptor] Accessibility permission detected and activated!")
            }
        }
    }

    // MARK: - Lifecycle

    /// Starts intercepting media keys if Accessibility permission is granted.
    func start() {
        guard checkPermission() else {
            print("[MediaKeyInterceptor] Cannot start: Accessibility permission not granted.")
            startPollingPermission()
            return
        }
        guard eventTap == nil else { return }

        // NX_SYSDEFINED events correspond to rawValue 14
        let sysDefinedType = CGEventType(rawValue: 14)!
        let eventMask = CGEventMask(1 << sysDefinedType.rawValue)

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return interceptor.handleEvent(event: event)
            },
            userInfo: selfPointer
        ) else {
            print("[MediaKeyInterceptor] Failed to create CGEvent tap.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        DispatchQueue.main.async {
            self.isListening = true
        }
        print("[MediaKeyInterceptor] Super Volume Keys active.")
    }

    /// Stops intercepting media keys and unregisters the event tap.
    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if Thread.isMainThread {
            self.isListening = false
        }
    }

    // MARK: - Event Dispatch

    private func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passRetained(event)
        }

        // Check for media key events (systemDefined with subtype 8)
        if nsEvent.type == .systemDefined && nsEvent.subtype.rawValue == 8 {
            let data1 = nsEvent.data1
            let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
            let keyFlags = (data1 & 0x0000FFFF)
            let keyState = (keyFlags & 0xFF00) >> 8

            // 0xA signifies key down (and repeats)
            if keyState == 0xA {
                let NX_KEYTYPE_SOUND_UP: Int32 = 0
                let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
                let NX_KEYTYPE_MUTE: Int32 = 7

                switch keyCode {
                case NX_KEYTYPE_SOUND_UP:
                    DispatchQueue.main.async { self.onVolumeUp?() }
                    return nil // Intercept & consume event

                case NX_KEYTYPE_SOUND_DOWN:
                    DispatchQueue.main.async { self.onVolumeDown?() }
                    return nil // Intercept & consume event

                case NX_KEYTYPE_MUTE:
                    DispatchQueue.main.async { self.onMuteToggle?() }
                    return nil // Intercept & consume event

                default:
                    break
                }
            }
        }

        return Unmanaged.passRetained(event)
    }
}
