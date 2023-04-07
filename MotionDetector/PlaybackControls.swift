import SwiftUI
import AVFoundation

/// A set of controls for video playback.
struct PlaybackControls: View {
    /// Responsible for playing the video.
    @Binding var player: AVPlayer

    /// The current playback rate.
    @Binding var rate: Float

    var body: some View {
        VStack {
            HStack {
                Button {
                    player.pause()
                    if player.currentItem?.canStepBackward ?? false {
                        player.currentItem?.step(byCount: -1)
                    }
                } label: {
                    Image(systemName: "backward.frame.fill")
                }

                Button {
                    player.increaseBackwardRate()
                    rate = player.rate
                } label: {
                    Image(systemName: "backward.fill")
                }

                Button {
                    if rate == 0 { player.play() }
                    else { player.pause() }
                    rate = player.rate
                } label: {
                    Image(systemName: rate == 0 ? "play.fill" : "pause.fill")
                }

                Button {
                    player.increaseForwardRate()
                    rate = player.rate
                } label: {
                    Image(systemName: "forward.fill")
                }

                Button {
                    player.pause()
                    if player.currentItem?.canStepBackward ?? false {
                        player.currentItem?.step(byCount: 1)
                    }
                } label: {
                    Image(systemName: "forward.frame.fill")
                }
            }

            Text("\(Int(rate))x")
                .frame(width: 50)
                .opacity(rate == 0 ? 0 : 1)
        }
    }
}

struct VideoPlaybackControls_Previews: PreviewProvider {
    @State static var player = AVPlayer()

    static var previews: some View {
        PlaybackControls(player: $player, rate: .constant(1))
    }
}

extension AVPlayer {
    /// Doubles the current rate, up to a maximum value.
    ///
    /// If the current rate is negative, it is instead reset to normal forward playback.
    func increaseForwardRate() {
        if rate <= 0 {
            rate = 1
        } else if rate < 64 {
            rate *= 2
        }
    }

    /// Doubles the backware playback rate, up to a maximum value.
    ///
    /// If the current rate is positive, it is instead reset to normal backward playback.
    func increaseBackwardRate() {
        if rate >= 0 {
            rate = -1
        } else if rate > -64 {
            rate *= 2
        }
    }
}
