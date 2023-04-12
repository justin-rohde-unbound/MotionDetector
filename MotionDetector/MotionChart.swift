import SwiftUI
import Charts

/// Plots the motion between frames over time.
struct MotionChart: View {
    /// The array of motion amounts by time to plot.
    @Binding var motionData: [MotionResult]?

    /// The array of human data ranges to highlight.
    @Binding var humanData: [(Double, Double)]

    @Binding var duration: Double!

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Chart {
                    if let motionData = motionData {
                        ForEach(motionData) { item in
                            LineMark(
                                x: .value("Time", item.time),
                                y: .value("Amount" , item.amount)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(Color.black)
                            .interpolationMethod(.cardinal)
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)

                Chart {
                    if let motionData = motionData {
                        ForEach(motionData) { item in
                            LineMark(
                                x: .value("Time", item.time),
                                y: .value("Amount" , item.amount)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.white)
                            .interpolationMethod(.cardinal)
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)

                ForEach(humanData, id: \.0) { result in
                    let left = result.0 / duration * geometry.size.width
                    let right = result.1 / duration * geometry.size.width
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: right-left)
                        .position(x: left + (right-left)/2, y: geometry.size.height / 2)
                }
            }
        }
    }
}
