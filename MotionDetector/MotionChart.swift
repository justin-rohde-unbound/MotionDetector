import SwiftUI
import Charts

/// Plots the motion between frames over time.
struct MotionChart: View {
    /// The array of motion amounts by time to plot.
    @Binding var motionData: [MotionResult]?

    var body: some View {
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
        }
    }
}
