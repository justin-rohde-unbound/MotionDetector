import AVFoundation

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

    /// Returns an async sequence of video frames at the specified times.
    ///
    /// - Parameters:
    ///   - times: The times at which to extract frames.
    ///   - tolerance: The time tolerance in seconds for each frame.
    ///   - maximumSize: An optional maximum size of image to return. If not specified, the unscaled asset size is used.
    /// - Returns: The sequence of extracted video frames.
    func frames(
        atTimes times: [CMTime],
        tolerance: Double,
        maximumSize: CGSize? = nil
    ) async -> AVAssetImageGenerator.Images {
        let requestedTolerance = CMTime(seconds: tolerance, preferredTimescale: 600)
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.requestedTimeToleranceBefore = requestedTolerance
        imageGenerator.requestedTimeToleranceAfter = requestedTolerance
        if let maximumSize = maximumSize {
            imageGenerator.maximumSize = maximumSize
        }

        return imageGenerator.images(for: times)
    }
}
