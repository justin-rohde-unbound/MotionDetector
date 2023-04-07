import SwiftUI

/// Represents the motion between a frame and the previous frame at an instant in the video timeline.
struct MotionResult: Identifiable {
    /// The time in the video timeline represented by this result.
    let time: Double

    /// The amount of difference between the frame at this time and the previous extracted frame.
    let amount: Float

    // MARK: - Identifiable conformance

    var id: Double { time }
}
