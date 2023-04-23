import SwiftUI
import AVFoundation

/// Displays a video player layer without any added controls.
struct AVPlayerView: NSViewRepresentable {
    /// The video player that controls what is displayed in the view.
    let videoPlayer: AVPlayer

    func makeNSView(context: Context) -> some NSView {
        AVPlayerNSView(videoPlayer)
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let view = nsView as? AVPlayerNSView else { return }

        // Make sure player is resized along with view
        view.playerLayer.bounds = view.bounds
    }
}

/// A simple view that displays video content, responding to commands from an AVPlayer.
class AVPlayerNSView: NSView {
    /// The layer that will display video content.
    let playerLayer = AVPlayerLayer()

    /// The player that controls video playback.
    let player: AVPlayer

    init(_ player: AVPlayer) {
        self.player = player
        super.init(frame: .zero)

        playerLayer.player = player
        playerLayer.backgroundColor = .black
        layer = playerLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
