import SwiftUI
import AVFoundation

/// Buttons to set the left and right boundaries of the clip, as well as to
/// trigger export of video from the clipped region.
struct ClippingControls: View {
    /// Performs the clip export and publishes state.
    @ObservedObject var clipExporter: ClipExporter

    /// The fraction of the clip start position to the video duration.
    @Binding var clipStartFraction: CGFloat

    /// The fraction of the clip end position to the video duration.
    @Binding var clipEndFraction: CGFloat

    /// The fraction of the current playhead position to the video duration.
    @Binding var playheadFraction: CGFloat

    /// Responsible for video playback.
    let videoPlayer: AVPlayer

    /// The current video URL, used to initialize clip export parameters.
    let videoURL: URL?

    var body: some View {
        HStack {
            Button {
                clipStartFraction = playheadFraction
                if clipEndFraction < clipStartFraction {
                    clipEndFraction = clipStartFraction
                }
            } label: {
                Image(systemName: "chevron.left.to.line")
            }
            .alert(item: $clipExporter.lastExportURL) { url in
                Alert(
                    title: Text("Clip Exported"),
                    message: Text("Successfully exported clip \(url.lastPathComponent)"),
                    primaryButton: .default(Text("OK")),
                    secondaryButton: .default(Text("Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                )
            }

            Button {
                if clipExporter.isExporting {
                    clipExporter.cancel()
                } else {
                    guard
                        let currentItem = videoPlayer.currentItem,
                        let videoURL = videoURL,
                        let outputURL = selectOutputVideoURL(
                            startingIn: videoURL.deletingLastPathComponent(),
                            preferredExtension: videoURL.pathExtension
                        )
                    else { return }

                    if outputURL.pathExtension.isEmpty {
                        clipExporter.error = .internal("No file extension specified.")
                        return
                    }

                    Task {
                        let videoDuration = currentItem.duration.seconds
                        let startTime = CMTime(
                            seconds: videoDuration * clipStartFraction,
                            preferredTimescale: 600
                        )
                        let endTime = CMTime(
                            seconds: videoDuration * clipEndFraction,
                            preferredTimescale: 600
                        )
                        let timeRange = CMTimeRange(start: startTime, end: endTime)

                        clipExporter.export(
                            asset: currentItem.asset,
                            timeRange: timeRange,
                            to: outputURL
                        )
                    }
                }
            } label: {
                Text(clipExporter.isExporting ? "Cancel" : "Export Clip")
            }
            .alert(item: $clipExporter.error) { error in
                Alert(title: Text("Error"), message: Text(error.description))
            }

            Button {
                clipEndFraction = playheadFraction
                if clipStartFraction > clipEndFraction {
                    clipStartFraction = clipEndFraction
                }
            } label: {
                Image(systemName: "chevron.right.to.line")
            }
        }
    }
}

