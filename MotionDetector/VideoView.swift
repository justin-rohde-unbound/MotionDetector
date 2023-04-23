import SwiftUI
import AVKit
import RangeSelector
import Carbon

/// Presents a video player with a preview thumbnail strip, scrubbing controls, and trimming controls.
struct PlayerView: View {
    /// The URL of the video to play.
    let videoURL: URL

    /// Manages video playback and reports current state while playing.
    @ObservedObject var playerManager: AVPlayerManager

    /// The results of any motion analysis to display as a chart if non-empty.
    @Binding var motionData: [MotionResult]

    /// The results of any human detection to display as a chart is non-empty.
    @Binding var humanData: [MotionResult]

    /// Manages export of video clips and publishes state.
    @ObservedObject var clipExporter: ClipExporter

    /// The start fraction of the clipping range.
    @State var clipStartFraction: CGFloat = 0

    /// The end fraction of the clipping range.
    @State var clipEndFraction: CGFloat = 1

    /// The current fraction of the playhead position along the timeline.
    @State var playheadFraction: CGFloat = 0

    /// Whether clipping is current enabled.
    @State var isClipping = false

    /// The current size of the motion chart area.
    @State var chartSize: CGSize?
    var body: some View {
        VStack {
            Text(videoURL.lastPathComponent)
            GeometryReader { geometry in
                AVPlayerView(videoPlayer: playerManager.player)
                    .background(Color.green)
            }

            GeometryReader { geometry in
                ZStack {
                    ThumbnailStrip(videoURL: videoURL)
                    MotionChart(motionData: $motionData, color: .white)
                    MotionChart(motionData: $humanData, color: .green)
                    PlayheadView(fraction: $playerManager.playheadFraction) { fraction in
                        playerManager.seekToFraction(fraction)
                    }

                    if isClipping {
                        RangeSelector(
                            leftFraction: $clipStartFraction,
                            rightFraction: $clipEndFraction,
                            color: Color(.systemYellow)
                        )
                        .onChange(of: clipStartFraction) { fraction in
                            playerManager.seekToFraction(fraction)
                        }
                        .onChange(of: clipEndFraction) { fraction in
                            playerManager.seekToFraction(fraction)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 50)
            .background(Color.black)

            FormattedTimeView(time: playerManager.currentTime)

            ZStack {
                HStack {
                    Button {
                        isClipping.toggle()
                    } label: {
                        ZStack {
                            Image(systemName: "timeline.selection")
                            if isClipping {
                                Image(systemName: "slash.circle")
                            }
                        }
                    }

                    if isClipping {
                        ClippingControls(
                            clipExporter: clipExporter,
                            clipStartFraction: $clipStartFraction,
                            clipEndFraction: $clipEndFraction,
                            playheadFraction: $playerManager.playheadFraction,
                            videoPlayer: playerManager.player,
                            videoURL: videoURL
                        )
                    }

                    Spacer()
                }

                PlaybackControls(playerManager: playerManager)
            }
        }
        .onChange(of: clipStartFraction) { fraction in
            playerManager.pause()
            playerManager.seekToFraction(fraction)
        }
        .onChange(of: clipEndFraction) { fraction in
            playerManager.pause()
            playerManager.seekToFraction(fraction)
        }
        .onChange(of: playheadFraction) { fraction in
            playerManager.seekToFraction(fraction)
        }
    }
}

extension PlayerView {
    /// Handles mouse and keyboard input.
    ///
    /// - Parameter event: The event that was sent to this view.
    func handleInputEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            switch Int(event.keyCode) {
            case kVK_LeftArrow:
                playerManager.stepBackward()
            case kVK_RightArrow:
                playerManager.stepForward()
            case kVK_ANSI_J:
                playerManager.increaseBackwardRate()
            case kVK_ANSI_K, kVK_Space:
                playerManager.togglePlayback()
            case kVK_ANSI_L:
                playerManager.increaseForwardRate()
            default:
                break
            }
        }
    }
}
