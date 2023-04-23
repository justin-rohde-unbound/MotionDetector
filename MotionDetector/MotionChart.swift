import SwiftUI
import Charts

/// Plots the motion between frames over time.
struct MotionChart: View {
    /// The array of motion amounts by time to plot.
    @Binding var motionData: [MotionResult]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Chart {
                    ForEach(motionData) { item in
                        LineMark(
                            x: .value("Time", item.time),
                            y: .value("Amount" , item.amount)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Color.black)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)

                Chart {
                    ForEach(motionData) { item in
                        LineMark(
                            x: .value("Time", item.time),
                            y: .value("Amount" , item.amount)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(color)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
    }
}
