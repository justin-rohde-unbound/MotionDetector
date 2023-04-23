import SwiftUI
import AVFoundation

class AVPlayerManager: ObservableObject {
    /// Whether seeking is currently underway. Tracked to prevent
    /// simultaneous seek operations.
    private var isSeeking = false

    /// The framerate of the current video.
    private var framerate: Float = 0

    /// The duration in seconds of the current video.
    private var duration: Double = 0

    /// The observer for video time changes.
    private var timeObserver: Any?

    /// The observer for boundary times.
    private var boundaryObserver: Any?

    /// Responsible for video playback.
    let player: AVPlayer

    /// The current fraction of playback time to video duration.
    @Published var playheadFraction: CGFloat = 0

    /// The current playback rate.
    @Published var rate: Float = 0

    /// The current playback position in seconds.
    @Published var currentTime: Double = 0

    init(player: AVPlayer) {
        self.player = player
    }

    /// Seek the video player to a point at a fraction of its timeline.
    ///
    /// - Parameters:
    ///   - fraction: The fraction of track duration to seek to.
    func seekToFraction(_ fraction: Double) {
        guard !isSeeking else { return }
        guard let seconds = player.currentItem?.duration.seconds else { return }

        isSeeking = true

        let isPlaying = rate != 0
        player.pause()

        let time = CMTime(seconds: seconds * fraction, preferredTimescale: 600)

        player.currentItem?.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { _ in
            self.isSeeking = false
            let actualTime = self.player.currentTime().seconds
            self.currentTime = actualTime
            self.playheadFraction = actualTime / self.duration
            if isPlaying { self.player.play() }
        }
    }

    /// Doubles the current rate, up to a maximum value.
    ///
    /// If the current rate is negative, it is instead reset to normal forward playback.
    func increaseForwardRate() {
        if player.rate <= 0 {
            player.rate = 1
        } else if player.rate < 64 {
            player.rate *= 2
        }

        rate = player.rate
    }

    /// Doubles the backware playback rate, up to a maximum value.
    ///
    /// If the current rate is positive, it is instead reset to normal backward playback.
    func increaseBackwardRate() {
        if player.rate >= 0 {
            player.rate = -1
        } else if player.rate > -64 {
            player.rate *= 2
        }

        rate = player.rate
    }

    func stepBackward() {
        player.pause()
        if player.currentItem?.canStepBackward ?? false {
            player.currentItem?.step(byCount: -1)
        }
        rate = 0
    }

    func stepForward() {
        player.pause()
        if player.currentItem?.canStepForward ?? false {
            player.currentItem?.step(byCount: 1)
        }
        rate = 0
    }

    func pause() {
        player.pause()
    }
    
    func togglePlayback() {
        if rate == 0 {
            player.play()
        }
        else {
            player.pause()
        }
        
        rate = player.rate
    }

    /// Resets the state of the application when a new URL is selected.
    ///
    /// This will clear the existing video and motion data, cancel any current motion
    /// calculations, and stop video playback before creating a new player.
    ///
    /// Basic video info is also captured for later calculations when seeking and plotting.
    ///
    /// - Parameter url: The URL of the new video to load.
    func loadURL(_ url: URL) {
        framerate = 0
        duration = 0
        rate = 0
        replaceVideoPlayerURL(with: url)
        seekToFraction(0)

        guard let asset = player.currentItem?.asset else { return }

        Task {
            guard let track = try? await asset.loadTracks(withMediaType: .video).first
            else { return }

            guard let (framerate, timeRange) = try? await track.load(.nominalFrameRate, .timeRange)
            else { return }

            self.framerate = framerate
            self.duration = timeRange.duration.seconds
        }
    }

    /// Replace or clear the current video player item.
    ///
    /// - Parameter newURL: The new video URL.
    func replaceVideoPlayerURL(with newURL: URL) {
        player.pause()

        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }

        if let boundaryObserver = boundaryObserver {
            NotificationCenter.default.removeObserver(boundaryObserver)
        }

        let asset = AVAsset(url: newURL)
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.02, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard self != nil else { return }
            self!.currentTime = time.seconds
            if self != nil, !self!.rate.isZero {
                self!.playheadFraction = self!.currentTime / self!.duration
            }
        }

        // Make sure the player controls return to correct state after player stops
        boundaryObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in self.rate = 0 }
    }
}
