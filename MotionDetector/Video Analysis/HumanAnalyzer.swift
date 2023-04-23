import SwiftUI
import Vision
import AVFoundation

struct HumanAnalyzer: VideoAnalyzer {
    static var title: String { "Human Detection" }

    func analyze(
        frames: AVAssetImageGenerator.Images,
        duration: Double,
        isCancelled: Binding<Bool>,
        progressUpdated: @escaping (Double) -> Void
    ) async -> Result<[MotionResult], VideoAnalysisError> {
        var humanData = [MotionResult]()
        let imagesByTime = frames.compactMap { try? ($0.actualTime, $0.image) }

        for await (time, image) in imagesByTime {
            if isCancelled.wrappedValue {
                return .failure(VideoAnalysisError.cancelled)
            }

            let motionAmount = image.hasHuman() ? 1.0 : 0.0
            let motionResult = MotionResult(time: time.seconds, amount: motionAmount)
            humanData.append(motionResult)

            DispatchQueue.main.async {
                progressUpdated(time.seconds / duration)
            }
        }

        return .success(humanData)
    }
}

fileprivate extension CGImage {
    /// - Returns: Whether a human is detected in the image.
    func hasHuman() -> Bool {
        let requestHandler = VNImageRequestHandler(cgImage: self)
        let request = VNDetectHumanRectanglesRequest()
        do {
            try requestHandler.perform([request])
            let isEmpty = request.results?.isEmpty ?? true
            return !isEmpty
        } catch {
            return false
        }
    }
}
