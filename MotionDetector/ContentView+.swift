import SwiftUI
import AVFoundation
import Carbon

extension ContentView {
    /// Resets the state of the application when a new URL is selected.
    ///
    /// This will clear the existing video and motion data, cancel any current motion
    /// calculations, and stop video playback before creating a new player.
    ///
    /// Basic video info is also captured for later calculations when seeking and plotting.
    ///
    /// - Parameter url: The URL of the new video to load.
    func loadURL(_ url: URL) {
        motionAnalyzer.cancel()
        framerate = nil
        duration = nil
        currentTime = 0
        rate = 0
        isClipping = false
        replaceVideoPlayerURL(with: url)
        seekToFraction(0)

        let asset = AVAsset(url: url)
        Task {
            guard let track = try? await asset.loadTracks(withMediaType: .video).first
            else { return }

            guard let (framerate, timeRange) = try? await track.load(.nominalFrameRate, .timeRange)
            else { return }

            self.framerate = framerate
            self.duration = timeRange.duration.seconds
        }
    }

    /// Seeks to the position in the video track corresponding to where the chart view that was tapped.
    ///
    /// - Parameter tappedFraction: The fraction of the x position to the width of the view.
    func handleManualPlayheadFractionChange(tappedFraction: Double) {
        let isPlaying = rate != 0
        videoPlayer.pause()
        playheadFraction = tappedFraction
        seekToFraction(tappedFraction)
        if isPlaying { videoPlayer.play() }
    }

    /// Handles mouse and keyboard input.
    ///
    /// - Parameter event: The event that was sent to this view.
    func handleInputEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            switch Int(event.keyCode) {
            case kVK_LeftArrow:
                step(byCount: -1)
            case kVK_RightArrow:
                step(byCount: 1)
            case kVK_ANSI_J:
                videoPlayer.increaseBackwardRate()
            case kVK_ANSI_K:
                videoPlayer.pause()
            case kVK_Space:
                if videoPlayer.rate == 0 { videoPlayer.play() }
                else { videoPlayer.pause() }
            case kVK_ANSI_L:
                videoPlayer.increaseForwardRate()
            case kVK_ANSI_I:
                clipStartFraction = playheadFraction
                if clipEndFraction < clipStartFraction { clipEndFraction = 1 }
            case kVK_ANSI_O:
                clipEndFraction = playheadFraction
                if clipStartFraction > clipEndFraction { clipStartFraction = 0 }
            default:
                break
            }
        }

        rate = videoPlayer.rate
    }

    /// Step the video player by a number of frames.
    ///
    /// - Parameter stepCount: The number of frames to move the playhead.
    private func step(byCount stepCount: Int) {
        videoPlayer.pause()
        videoPlayer.currentItem?.step(byCount: stepCount)
        if let duration = duration {
            playheadFraction = videoPlayer.currentTime().seconds / duration
        }
    }

    /// Replace or clear the current video player item.
    ///
    /// - Parameter videoURL: The new video URL.
    func replaceVideoPlayerURL(with newURL: URL?) {
        videoPlayer.pause()

        if let timeObserver = timeObserver {
            videoPlayer.removeTimeObserver(timeObserver)
        }

        if let boundaryObserver = boundaryObserver {
            NotificationCenter.default.removeObserver(boundaryObserver)
        }

        guard let newURL = newURL else {
            videoPlayer.replaceCurrentItem(with: nil)
            return
        }

        let asset = AVAsset(url: newURL)
        videoPlayer.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        videoURL = newURL

        timeObserver = videoPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { time in
            guard let duration = duration else { return }
            currentTime = time.seconds
            if !rate.isZero { playheadFraction = currentTime / duration }
        }

        // Make sure the player controls return to correct state after player stops
        boundaryObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: videoPlayer.currentItem,
            queue: .main
        ) { _ in self.rate = 0 }
    }

    /// Seek the video player to a point at a fraction of its timeline.
    ///
    /// - Parameter fraction: The fraction to seek to.
    func seekToFraction(_ fraction: Double) {
        guard !isSeeking else { return }
        isSeeking = true

        if let seconds = videoPlayer.currentItem?.duration.seconds {
            let time = CMTime(seconds: seconds * fraction, preferredTimescale: 600)
            let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
            videoPlayer.currentItem?.seek(
                to: time,
                toleranceBefore: tolerance,
                toleranceAfter: tolerance
            ) { _ in isSeeking = false }
        }
    }
}
