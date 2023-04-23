import SwiftUI
import AVFoundation

/// A set of controls for video playback.
struct PlaybackControls: View {
    @ObservedObject var playerManager: AVPlayerManager

    var body: some View {
        VStack {
            HStack {
                Text("\(Int(-playerManager.rate))x")
                    .frame(width: 30)
                    .opacity(playerManager.rate < 0 ? 1 : 0)

                Button {
                    playerManager.stepBackward()
                } label: {
                    Image(systemName: "backward.frame.fill")
                }

                Button {
                    playerManager.increaseBackwardRate()
                } label: {
                    Image(systemName: "backward.fill")
                }

                Button {
                    playerManager.togglePlayback()
                } label: {
                    Image(systemName: playerManager.rate == 0 ? "play.fill" : "pause.fill")
                }

                Button {
                    playerManager.increaseForwardRate()
                } label: {
                    Image(systemName: "forward.fill")
                }

                Button {
                    playerManager.stepForward()
                } label: {
                    Image(systemName: "forward.frame.fill")
                }

                Text("\(Int(playerManager.rate))x")
                    .frame(width: 30)
                    .opacity(playerManager.rate > 0 ? 1 : 0)
            }
        }
    }
}

struct VideoPlaybackControls_Previews: PreviewProvider {
    @StateObject static var playerManager = AVPlayerManager(player: AVPlayer())

    static var previews: some View {
        PlaybackControls(playerManager: playerManager)
    }
}
