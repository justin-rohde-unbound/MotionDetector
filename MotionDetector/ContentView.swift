import SwiftUI
import UniformTypeIdentifiers
import AVKit
import Carbon
import RangeSelector

/// The main content view, where the video player and motion information will be displayed.
///
/// This view also contains the controls for choosing a video, running analysis, creating
/// output files, and adjusting settings for the analysis.
struct ContentView: View {
    /// Compares video frames and publishes status.
    @StateObject var motionAnalyzer = MotionAnalyzer()

    /// Exports video clips in the selected time range and publishes status.
    @StateObject var clipExporter = ClipExporter()

    /// The player for the current video.
    @State var videoPlayer = AVPlayer(playerItem: nil)

    /// The URL of the current video file.
    @State var videoURL: URL?

    /// The current fraction of playback time to video duration.
    @State var playheadFraction: CGFloat = 0

    /// The current playback rate.
    @State var rate: Float = 0

    /// The framerate of the current video.
    @State var framerate: Float?

    /// The duration in seconds of the current video.
    @State var duration: Double?

    /// The observer for video time changes.
    @State var timeObserver: Any?

    /// The observer for boundary times.
    @State var boundaryObserver: Any?

    /// The start fraction of the clipping range.
    @State var clipStartFraction: CGFloat = 0.25

    /// The end fraction of the clipping range.
    @State var clipEndFraction: CGFloat = 0.75

    /// The current playback position in seconds.
    @State var currentTime: Double = 0

    /// The analysis interval in seconds.
    @State var interval: Double = 1.0

    /// Whether clipping is current enabled.
    @State var isClipping = false

    /// Whether the video player is seeking to a position.
    @State var isSeeking = false

    /// The current size of the motion chart area.
    @State var chartSize: CGSize?

    /// A decimal number formatter showing 2 fraction digits.
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        VStack(spacing: 10) {
            if videoPlayer.currentItem == nil {
                Spacer()
                Text("Open or drop video file.")
                Spacer()
            } else {
                if let videoURL = videoURL {
                    Text(videoURL.lastPathComponent)
                    GeometryReader { geometry in
                        PlayerView(videoPlayer: videoPlayer)
                            .background(Color.green)
                    }
                }

                GeometryReader { geometry in
                    ZStack {
                        ThumbnailStrip(videoURL: $videoURL)
                        MotionChart(motionData: $motionAnalyzer.results)
                        PlayheadView(fraction: $playheadFraction) { fraction in
                            handleManualPlayheadFractionChange(tappedFraction: fraction)
                        }

                        if isClipping {
                            RangeSelector(
                                leftFraction: $clipStartFraction,
                                rightFraction: $clipEndFraction,
                                color: Color(.systemYellow)
                            )
                            .onChange(of: clipStartFraction) { fraction in
                                playheadFraction = fraction
                                seekToFraction(fraction)
                            }
                            .onChange(of: clipEndFraction) { fraction in
                                playheadFraction = fraction
                                seekToFraction(fraction)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color.black)

                FormattedTimeView(time: currentTime)

                PlaybackControls(player: $videoPlayer, rate: $rate)
            }

            ZStack {
                VStack {
                    ProgressView(value: motionAnalyzer.progress)
                    Text("Analyzing for motion...")
                }
                .opacity(motionAnalyzer.isRunning ? 1 : 0)

                VStack {
                    ProgressView(value: clipExporter.progress)
                    Text("Exporting clip...")
                }
                .opacity(clipExporter.isExporting ? 1 : 0)
            }

            HStack {
                Spacer()
                Text("Analyze every")
                TextField(value: $interval, formatter: Self.formatter, label: { })
                .frame(width: 50)
                Text("seconds")
            }

            HStack {
                Button("Open Video...") {
                    if let url = selectSourceVideoURL() { loadURL(url) }
                }
                .keyboardShortcut("o", modifiers: .command)

                Spacer()

                HStack {
                    if !clipExporter.isExporting {
                        Button {
                            isClipping.toggle()
                        } label: {
                            Text((isClipping ? "Hide" : "Show") + " Clipping Controls")
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
                    }

                    if isClipping {
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
                    }
                }

                Spacer()

                if motionAnalyzer.isRunning {
                    Button("Cancel") { motionAnalyzer.cancel() }
                } else {
                    Button("Analyze Motion") {
                        motionAnalyzer.videoURL = videoURL

                        // Restrict analysis interval to one frame to prevent invalid zero amounts
                        if let framerate = framerate {
                            let interval = max(self.interval, 1.0 / Double(framerate))
                            motionAnalyzer.start(withInterval: interval)
                        } else {
                            motionAnalyzer.start(withInterval: interval)
                        }
                    }
                    .disabled(videoURL == nil)
                    .alert(item: $motionAnalyzer.error) { error in
                        Alert(title: Text("Error"), message: Text(error.localizedDescription))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onDrop(of: [.fileURL], isTargeted: nil) { provider in
            provider.first?.loadDataRepresentation(
                forTypeIdentifier: UTType.fileURL.identifier
            ) { data, _ in
                if let data = data,
                   let path = NSString(data: data, encoding: NSUTF8StringEncoding),
                   let url = URL(string: path as String)
                {
                    loadURL(url)
                }
            }
            return true
        }
        .overlay {
            InputAwareView { event in
                handleInputEvent(event)
            }
            .opacity(0.5)
        }
        .onChange(of: clipStartFraction) { fraction in
            videoPlayer.pause()
            rate = 0
            seekToFraction(fraction)
        }
        .onChange(of: clipEndFraction) { fraction in
            videoPlayer.pause()
            rate = 0
            seekToFraction(fraction)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let url = URL(string: "https://sample-videos.com/video123/mp4/480/big_buck_bunny_480p_1mb.mp4")!
            ContentView(videoURL: url)
        }
    }
}

/// Allows the user to select a movie or video file.
///
/// - Returns: The URL of the file that was selected, or nil if no file was selected.
func selectSourceVideoURL() -> URL? {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = true
    panel.allowedContentTypes = [.movie, .video]
    return panel.runModal() == .OK ? panel.urls.first : nil
}

/// Allows the user to select or specify a URL for output.
///
/// - Parameters:
///     - directoryURL: The URL of the directory to start in.
///     - preferredExtension: The preferred filename extension, which will be used to auto-populate
///     the initial name field value.
/// - Returns: The URL of the file that was created/selected, or nil if canceled.
func selectOutputVideoURL(startingIn directoryURL: URL, preferredExtension: String) -> URL? {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.canSelectHiddenExtension = true
    panel.canHide = true
    panel.isExtensionHidden = false
    panel.directoryURL = directoryURL
    panel.nameFieldStringValue = "Untitled.\(preferredExtension)"
    panel.allowedContentTypes = [UTType.movie]

    return panel.runModal() == .OK ? panel.url : nil
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}
