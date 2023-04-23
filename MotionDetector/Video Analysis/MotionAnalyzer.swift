import SwiftUI
import Vision
import AVFoundation

/// Analyzes the difference between sequential video frames for motion. Uses the Vision framework
/// to measure motion as the inverse of the similarity between two images.
struct MotionAnalyzer: VideoAnalyzer {
    static var title: String { "Motion Detection" }

    func analyze(
        frames: AVAssetImageGenerator.Images,
        duration: Double,
        isCancelled: Binding<Bool>,
        progressUpdated: @escaping (Double) -> Void
    ) async -> Result<[MotionResult], VideoAnalysisError> {
        // Collect motion data by time position
        var motionData = [MotionResult]()
        var previousObservation: VNFeaturePrintObservation?

        let imagesByTime = frames.compactMap { try? ($0.actualTime, $0.image) }

        for await (time, cgImage) in imagesByTime {
            if isCancelled.wrappedValue {
                return .failure(.cancelled)
            }

            guard let currentObservation = cgImage.featurePrintObservation() else {
                return .failure(.frameAnalysis("Unable to create feature print observation for frame."))
            }

            if let previousObservation = previousObservation {
                do {
                    var distance = Float(0)
                    try currentObservation.computeDistance(&distance, to: previousObservation)
                    motionData.append(MotionResult(time: time.seconds, amount: Double(distance)))
                } catch {
                    return .failure(.frameAnalysis("Unable to calculate distance between frames."))
                }
            } else {
                motionData.append(MotionResult(time: 0, amount: 0))
            }

            previousObservation = currentObservation

            DispatchQueue.main.async {
                progressUpdated(time.seconds / duration)
            }
        }

        return .success(motionData)
    }
}

fileprivate extension CGImage {
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
}

