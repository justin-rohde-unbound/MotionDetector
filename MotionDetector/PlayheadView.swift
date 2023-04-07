import SwiftUI

/// Displays a red bar indicating the current position of the playhead int the video timeline.
///
/// This view also handles all mouse interactions that manually change the playhead position.
struct PlayheadView: View {
    /// Publishes limited position changes when scrubbing occurs.
    @StateObject private var selectedFraction = Throttled<CGFloat>(delay: 0.01)

    /// The fraction of the video duration where the playhead is located.
    @Binding var fraction: CGFloat

    /// Handler for playhead changes from the chart.
    let onFractionChangedManually: (Double) -> ()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.opacity(0.001)

                Path { path in
                    let x = fraction * geometry.size.width
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(lineWidth: 1.0)
                .foregroundColor(.red)
            }
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let fraction = drag.location.x / geometry.size.width
                selectedFraction.input = max(0, min(fraction, 1))
            })
            .onChange(of: selectedFraction.value) { value in
                if let value = value {
                    onFractionChangedManually(value)
                }
            }
        }
    }
}
