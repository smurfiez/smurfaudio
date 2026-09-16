import SwiftUI

@main
struct SmurfAudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var audioState = AudioState()

    var body: some Scene {
        // Menu bar extra - primary agent interface
        MenuBarExtra("SmurfAudio", systemImage: "waveform.circle.fill") {
            PopoverContentView(audioState: audioState)
                .onAppear {
                    appDelegate.audioState = audioState
                }
        }
        .menuBarExtraStyle(.window)
    }
}
