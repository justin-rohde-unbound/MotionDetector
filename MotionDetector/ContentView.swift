import SwiftUI
import UniformTypeIdentifiers
import AVKit
import Carbon

let analyzerTitles = [
    MotionAnalyzer.title,
    HumanAnalyzer.title
]

/// The main content view, where the video player and motion information will be displayed.
///
/// This view also contains the controls for choosing a video, running analysis, creating
/// output files, and adjusting settings for the analysis.
struct ContentView: View {
    /// Compares video frames and publishes status.
    @StateObject var motionAnalyzer = VideoAnalysisManager(analyzer: MotionAnalyzer())

    /// Detecets humans in video frames.
    @StateObject var humanDetector = VideoAnalysisManager(analyzer: HumanAnalyzer())

    /// Exports video clips in the selected time range and publishes status.
    @StateObject var clipExporter = ClipExporter()

    /// Manages video playback.
    @StateObject var playerManager = AVPlayerManager(player: AVPlayer())

    /// The analysis interval in seconds.
    @State var interval: Double = 2.0

    /// Identifies the selected type of analysis to run.
    @State var selectedAnalyzerTitle = MotionAnalyzer.title

    /// The URL of the video to analyze.
    @State var videoURL: URL?

    /// A decimal number formatter showing up to 3 fraction digits.
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    var body: some View {
        VStack(spacing: 10) {
            if let videoURL = videoURL {
                PlayerView(
                    videoURL: videoURL,
                    playerManager: playerManager,
                    motionData: $motionAnalyzer.results,
                    humanData: $humanDetector.results,
                    clipExporter: clipExporter
                )
            } else {
                Spacer()
                Text("Open or drop video file.")
                Spacer()
            }

            ZStack {
                VStack {
                    VStack {
                        HStack {
                            ProgressView(value: motionAnalyzer.progress)
                            Button {
                                motionAnalyzer.cancel()
                            } label: {
                                Image(systemName: "x.circle.fill").foregroundColor(.red)
                            }.buttonStyle(.borderless)
                        }
                        Text("Analyzing for motion...")
                    }
                    .opacity(motionAnalyzer.isRunning ? 1 : 0)

                    VStack {
                        HStack {
                            ProgressView(value: humanDetector.progress)
                            Button {
                                humanDetector.cancel()
                            } label: {
                                Image(systemName: "x.circle.fill").foregroundColor(.red)
                            }.buttonStyle(.borderless)
                        }
                        Text("Detecting humans...")
                    }
                    .opacity(humanDetector.isRunning ? 1 : 0)
                }

                VStack {
                    ProgressView(value: clipExporter.progress)
                    Text("Exporting clip...")
                }
                .opacity(clipExporter.isExporting ? 1 : 0)
            }

            ZStack {
                HStack {
                    Button("Open Video...") {
                        if let url = selectSourceVideoURL() {
                            self.videoURL = url
                        }
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Spacer()
                }

                if let asset = playerManager.player.currentItem?.asset {
                    HStack {
                        Spacer()

                        Text("Analyze every")
                        // TODO restrict value to duration of single frame
                        TextField(value: $interval, formatter: Self.formatter, label: { })
                            .frame(width: 50)
                        Text("seconds")
                            .padding(.trailing, 10)

                        Picker(selection: $selectedAnalyzerTitle) {
                            ForEach(analyzerTitles, id: \.self) { title in
                                Text(title)
                            }
                        } label: {}
                        .pickerStyle(.menu)
                        .frame(width: 150)

                        Button("Run") {
                            switch selectedAnalyzerTitle {
                            case MotionAnalyzer.title:
                                motionAnalyzer.run(asset: asset, interval: interval)
                            case HumanAnalyzer.title:
                                humanDetector.run(asset: asset, interval: interval)
                            default:
                                break
                            }
                        }
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
                    self.videoURL = url
                }
            }
            return true
        }
        .onChange(of: videoURL) { url in
            if let url = url {
                playerManager.loadURL(url)
                motionAnalyzer.cancel()
                humanDetector.cancel()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let url = URL(string: "https://sample-videos.com/video123/mp4/480/big_buck_bunny_480p_1mb.mp4")!
            ContentView(videoURL: url)
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
///    - directoryURL: The URL of the directory to start in.
///    - preferredExtension: The preferred filename extension, which will be used to auto-populate the initial name field value.
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
