import Vision
import Combine
import AVFoundation
import Accelerate
import SwiftUI

/// Errors that can occur when extracting and comparing video still frames.
enum MotionAnalysisError: String, Error, Identifiable {
    case noURL = "No URL is selected for analysis."
    case invalidVideoFile = "The selected file is not a valid video."
    case unableToLoadTrackData = "Unable to load video data."
    case unableToCalculateFrameDistance = "Unable to determine motion between frames."
    case unableToCreateFeaturePrint = "Unable to analyze video frame."
    case cancelled = "The operation was cancelled by the user."

    var id: String { self.rawValue }
}

/// An observable object that processes video frames for motion identification.
///
/// Maintains the current state of the operation for reporting to the calling process.
class MotionAnalyzer: ObservableObject {
    /// The current fraction of frames processed.
    @Published var progress = 0.0

    /// Whether frames are currently being processed for motion.
    @Published var isRunning = false

    /// Total motion found vs. time.
    @Published var motionResults: [MotionResult]?

    /// Start and end of ranges where humans are detected, in seconds.
    @Published var humanResults: [(Double, Double)] = []

    /// The error that occured during processing, or nil if no errors occurred.
    @Published var error: MotionAnalysisError?

    /// A user flag to indicate request for cancellation.
    ///
    /// Setting this flag does not instantly end processing, but tells the calculation
    /// method to stop at the next interval and return an empty result array.
    private var isCancelled = false

    /// The URL to the video file from which to extract frames.
    var videoURL: URL?

    /// If running, sets the cancel flag to tell the analyzer to stop.
    func cancel() {
        if isRunning {
            isCancelled = true
        } else {
            clear()
        }
    }

    /// Reset to initial state.
    func clear() {
        progress = 0
        isRunning = false
        isCancelled = false
        error = nil
        motionResults = nil
        humanResults = []
    }

    /// Sets published state and begins motion analysis.
    ///
    /// - Parameter interval: The interval at which frames will be extracted for comparison.
    func start(withInterval interval: Double) {
        clear()
        isRunning = true

        Task {
            let results = await analyze(atInterval: interval)

            DispatchQueue.main.async {
                self.progress = 0
                self.isRunning = false
                self.isCancelled = false

                switch results {
                case .success(let results):
                    self.motionResults = results.0
                    self.humanResults = results.1
                case .failure(let error):
                    guard let motionError = error as? MotionAnalysisError,
                          motionError != .cancelled
                    else { return }

                    self.error = motionError
                }
            }
        }
    }

    /// Returns an array of motion data for video frames extracted at the specified interval.
    ///
    /// This method first sets up an array of times at which to extract frames. Each frame
    /// is then compared for motion with the previous frame and the result is returned along
    /// with the time of the 2nd extracted frame.
    ///
    /// - Parameter interval: The number of seconds between frames to compare.
    /// - Returns: The motion data for the calculated frames.
    func analyze(atInterval interval: Double) async -> Result<([MotionResult], [(Double, Double)]), Error> {
        // Extract images to compare
        guard let videoURL = videoURL else {
            return .failure(MotionAnalysisError.noURL)
        }

        let asset = AVAsset(url: videoURL)
        guard let duration = await asset.videoDuration() else {
            return .failure(MotionAnalysisError.unableToLoadTrackData)
        }

        guard let videoTrack = try? await asset.load(.tracks).first else {
            return .failure(MotionAnalysisError.unableToLoadTrackData)
        }

        guard let naturalSize = try? await videoTrack.load(.naturalSize) else {
            return .failure(MotionAnalysisError.unableToLoadTrackData)
        }

        let generatedImages = asset.asyncImageSequence(
            interval: interval,
            duration: duration,
            maximumSize: naturalSize //CGSize(width: 100, height: 100)
        )

        let imagesByTime = generatedImages.compactMap { try? ($0.actualTime, $0.image) }

        // Collect motion data by time position
        var motionData = [MotionResult]()
        var humanData = [(Double, Double)]()
        var previousObservation: VNFeaturePrintObservation?
        var humanStart: Double?

        for await (time, cgImage) in imagesByTime {
            if isCancelled {
                return .failure(MotionAnalysisError.cancelled)
            }

            guard let currentObservation = cgImage.featurePrintObservation() else {
                return .failure(MotionAnalysisError.unableToCreateFeaturePrint)
            }

            if let previousObservation = previousObservation {
                do {
                    var distance = Float(0)
                    try currentObservation.computeDistance(&distance, to: previousObservation)
                    motionData.append(MotionResult(time: time.seconds, amount: distance))
                } catch {
                    return .failure(MotionAnalysisError.unableToCalculateFrameDistance)
                }
            } else {
                motionData.append(MotionResult(time: 0, amount: 0))
            }

            if cgImage.hasHuman() {
                if humanStart == nil { humanStart = time.seconds }
            } else {
                if humanStart != nil {
                    humanData.append((humanStart!, time.seconds))
                    humanStart = nil
                }
            }

            previousObservation = currentObservation

            DispatchQueue.main.async {
                self.progress = time.seconds / duration
            }
        }

        return .success((motionData, humanData))
    }
}

extension CGImage {
    /// Returns a feature print observation of this image, which can be used for comparison with another image.
    ///
    /// - Returns: The feature print observation from this image, or nil if it could not be generated.
    func featurePrintObservation() -> VNFeaturePrintObservation? {
        let requestHandler = VNImageRequestHandler(cgImage: self)
        let request = VNGenerateImageFeaturePrintRequest()
        do {
            try requestHandler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            print(error)
            return nil
        }
    }

    func hasHuman() -> Bool {
        let requestHandler = VNImageRequestHandler(cgImage: self)
        let request = VNDetectHumanRectanglesRequest()
        do {
            try requestHandler.perform([request])
            let isEmpty = request.results?.isEmpty ?? true
            return !isEmpty
        } catch {
            print(error)
            return false
        }
    }
}

extension AVAsset {
    /// - Returns: The duration of this asset's first video track in seconds.
    func videoDuration() async -> Double? {
        let track = try? await loadTracks(withMediaType: .video).first
        return try? await track?.load(.timeRange).duration.seconds
    }

    /// - Returns: The video frames per second.
    func framerate() async -> Float? {
        let track = try? await loadTracks(withMediaType: .video).first
        return try? await track?.load(.nominalFrameRate)
    }

    /// Returns an async sequence of images extracted at the specified times.
    ///
    /// - Parameters:
    ///   - interval: The interval in seconds between frames.
    ///   - duration: The duration of the asset.
    ///   - maximumSize: The maximum size of images to generate.
    /// - Returns: The async sequence of extracted images.
    func asyncImageSequence(interval: Double, duration: Double, maximumSize: CGSize?) -> AVAssetImageGenerator.Images {
        let imageTimes = stride(from: 0.0, to: duration, by: interval).map {
            CMTime(seconds: $0, preferredTimescale: 600)
        }
        let imageGenerator = AVAssetImageGenerator(asset: self)
        if let maximumSize = maximumSize { imageGenerator.maximumSize = maximumSize }
        let tolerance = CMTime(seconds: interval / 4.0, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceBefore = tolerance //.zero
        imageGenerator.requestedTimeToleranceAfter = tolerance //.zero
        return imageGenerator.images(for: imageTimes)
    }
}
