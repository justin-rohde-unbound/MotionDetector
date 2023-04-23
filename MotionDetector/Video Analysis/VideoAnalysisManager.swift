import SwiftUI
import AVFoundation

/// Analyzes video frames using a supplier VideoAnalyzer instance.
///
/// Handles start and cancel operations and publishes the current state.
class VideoAnalysisManager: ObservableObject {
    /// The current fraction of frames processed.
    @Published var progress = 0.0

    /// Whether analysis is currently running.
    @Published var isRunning = false

    /// Ananlysis results per frame.
    @Published var results: [MotionResult] = []

    /// The error that occured during processing, or nil if no errors occurred.
    @Published var error: VideoAnalysisError?

    /// Runs analysis using the provided frames.
    private let analyzer: any VideoAnalyzer

    /// Flags any running analysis to stop and return an empty result.
    private var isCancelled = false

    init(analyzer: VideoAnalyzer) {
        self.analyzer = analyzer
    }

    /// If running, sets the cancel flag to tell the analyzer to stop.
    func cancel() {
        if isRunning {
            isCancelled = true
        } else {
            resetState()
        }
    }

    /// Reset to initial state.
    func resetState() {
        progress = 0
        isRunning = false
        isCancelled = false
        error = nil
        results = []
    }

    /// Runs the video analysis while publishing state updates.
    ///
    /// - Parameters:
    ///   - asset: The video asset to analyze.
    ///   - interval: The interval between frames to analyze.
    func run(asset: AVAsset, interval: Double) {
        guard !isRunning else { return }
        
        resetState()

        Task {
            guard let duration = try? await asset.load(.duration).seconds else {
                return
            }

            DispatchQueue.main.async {
                self.isRunning = true
            }

            // Extract frames from the video at the specified intervals
            let frameTimes = stride(from: 0.0, to: duration, by: interval).map {
                CMTime(seconds: $0, preferredTimescale: 600)
            }

            // Initiate frame analysis and report progress.
            let frames = await asset.frames(atTimes: frameTimes, tolerance: interval / 4.0)
            let results = await analyzer.analyze(
                frames: frames,
                duration: duration,
                isCancelled: Binding<Bool> {
                    self.isCancelled
                } set: {
                    self.isCancelled = $0
                }
            ) { progress in
                self.progress = progress
            }

            // Clean up and store any error that occurred during analysis
            DispatchQueue.main.async {
                self.progress = 0
                self.isRunning = false
                self.isCancelled = false

                switch results {
                case .success(let results):
                    self.results = results
                case .failure(let error):
                    if case .cancelled = error { return }
                    self.error = error
                }
            }
        }
    }
}
