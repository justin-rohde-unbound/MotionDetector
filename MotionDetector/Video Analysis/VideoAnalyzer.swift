import SwiftUI
import AVFoundation

protocol VideoAnalyzer {
    /// A title to show describing the type of analysis being performed.
    static var title: String { get }
    
    /// Returns the result of analysis on a per-frame basis.
    ///
    /// - Parameters:
    ///   - frames: The video frames to analyze.
    ///   - duration: The total duration of the source video, for progress tracking.
    ///   - isCancelled: Whether the user has requested cancellation.
    ///   - progressUpdated: Closure called each time progress is updated.
    /// - Returns: An array of motion results containing the amount of motion detected in each frame.
    func analyze(
        frames: AVAssetImageGenerator.Images,
        duration: Double,
        isCancelled: Binding<Bool>,
        progressUpdated: @escaping (Double) -> Void
    ) async -> Result<[MotionResult], VideoAnalysisError>
}
