import SwiftUI

/// SoundSource-style green track slider with a rounded pill thumb and percentage readout.
struct SoundSourceSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float> = 0...1
    var isMuted: Bool = false
    var isBoosted: Bool = false

    // Vibrant SoundSource green
    private let activeColor = Color(red: 0.17, green: 0.76, blue: 0.41)
    private let mutedColor = Color.gray.opacity(0.5)

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let thumbWidth: CGFloat = 16
                let thumbHeight: CGFloat = 12
                let effectiveVal = max(range.lowerBound, min(range.upperBound, value))
                let normalized = CGFloat((effectiveVal - range.lowerBound) / (range.upperBound - range.lowerBound))
                let fillWidth = max(0, min(width, width * normalized))

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.primary.opacity(0.10))
                        .frame(height: 4)

                    // Active fill
                    Capsule()
                        .fill(isMuted ? mutedColor : activeColor)
                        .frame(width: fillWidth, height: 4)

                    // Thumb pill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 1)
                        .frame(width: thumbWidth, height: thumbHeight)
                        .offset(x: max(0, min(width - thumbWidth, (width - thumbWidth) * normalized)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard !isMuted else { return }
                            let clampedX = max(0, min(width, gesture.location.x))
                            let fraction = Float(clampedX / width)
                            let newVal = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                            value = round(newVal * 100) / 100
                        }
                )
            }
            .frame(height: 18)

            // Percentage Readout
            Text("\(Int(round(value * 100))) %")
                .font(.system(size: 11, weight: .medium, design: .default))
                .monospacedDigit()
                .foregroundStyle(isMuted ? .secondary : .primary)
                .frame(width: 42, alignment: .trailing)
        }
    }
}
