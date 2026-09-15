import SwiftUI

/// SoundSource-style vertical level indicator pill.
struct LevelMeterPill: View {
    var isActive: Bool = false
    var level: CGFloat = 0.6 // 0.0 to 1.0

    private let greenColor = Color(red: 0.17, green: 0.76, blue: 0.41)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background pill
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 6, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                )

            // Active level fill
            if isActive {
                RoundedRectangle(cornerRadius: 3)
                    .fill(greenColor)
                    .frame(width: 6, height: max(3, 18 * level))
                    .animation(.easeInOut(duration: 0.2), value: level)
            }
        }
        .frame(width: 8, height: 18)
    }
}
