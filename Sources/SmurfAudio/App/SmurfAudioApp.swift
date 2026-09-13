import SwiftUI

@main
struct SmurfAudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var audioState = AudioState()

    var body: some Scene {
        // Main visible window on launch
        Window("SmurfAudio", id: "main") {
            PopoverContentView(audioState: audioState)
                .onAppear {
                    appDelegate.audioState = audioState
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 360, height: 520)

        // Menu bar extra
        MenuBarExtra("SmurfAudio", systemImage: "waveform.circle.fill") {
            PopoverContentView(audioState: audioState)
        }
        .menuBarExtraStyle(.window)
    }
}
