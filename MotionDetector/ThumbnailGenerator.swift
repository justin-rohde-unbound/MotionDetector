import SwiftUI
import AVFoundation

/// Generates thumbnails from a video asset.
class ThumbnailGenerator: ObservableObject {
    /// Thumbnails generated at various points along the video timeline.
    @Published var thumbnails: [NSImage] = []

    /// Generates video thumbnails to fill a certain amount of space horizontally, and publishes the result.
    ///
    /// - Parameters:
    ///   - url: The URL of the video asset from which to extract thumbnails.
    ///   - size: The size of the view in which all thumbnails must fit.
    func generateThumbnails(fromURL url: URL, forContainerSize size: CGSize) {
        let asset = AVAsset(url: url)
        Task {
            let thumbnailResult = await generateThumbnailsAsync(from: asset, toFillSize: size)
            DispatchQueue.main.async {
                if case .success(let thumbnails) = thumbnailResult {
                    self.thumbnails = thumbnails
                } else {
                    self.thumbnails = []
                }
            }
        }
    }

    /// Extracts thumbnails from a video such that the sequence will fill their
    /// container view horizontally.
    ///
    /// - Parameters:
    ///   - asset: The asset from which to extract images.
    ///   - size: The size of the view in which all thumbnails must fit.
    /// - Returns: An array of thumbnail images corresponding to the
    /// position in the video timeline where they appear.
    func generateThumbnailsAsync(
        from asset: AVAsset,
        toFillSize containerSize: CGSize
    ) async -> Result<[NSImage], MotionAnalysisError> {
        guard
            let track = try? await asset.loadTracks(withMediaType: .video).first,
            let videoSize = try? await track.load(.naturalSize),
            let duration = try? await asset.load(.duration)
        else {
            return .failure(MotionAnalysisError.unableToLoadTrackData)
        }

        let thumbnailWidth = (videoSize.width / videoSize.height) * containerSize.height
        let thumbnailSize = CGSize(width: thumbnailWidth, height: containerSize.height)
        let interval = duration.seconds * (thumbnailWidth / containerSize.width)
        let images = asset.asyncImageSequence(
            interval: interval,
            duration: duration.seconds,
            maximumSize: thumbnailSize
        )

        var thumbnails = [NSImage]()
        for await asyncImage in images {
            guard let cgImage = try? asyncImage.image else { continue }
            thumbnails.append(NSImage(cgImage: cgImage, size: thumbnailSize))
        }

        return .success(thumbnails)
    }
}
