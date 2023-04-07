import SwiftUI
import AVFoundation

/// Errors that can occur during export of a video clip.
enum ClipExportError: Error, Identifiable {
    case invalidExportSession
    case incompatibleOutputFileType(String)
    case `internal`(String)

    var description: String {
        switch self {
        case .incompatibleOutputFileType(let type):
            return "Incompatible output file type: \"\(type)\"."
        case .internal(let message):
            return message
        case .invalidExportSession:
            return "Unable to create export session."
        }
    }

    var id: String { description }
}

/// Exports video clips to file and publishes progress state.
class ClipExporter: ObservableObject {
    /// Whether a clip is being exported.
    @Published var isExporting = false

    /// The fraction of progress complete.
    @Published var progress = 0.0

    /// The last error that occurred, if any.
    @Published var error: ClipExportError?

    /// The last URL that was exported.
    @Published var lastExportURL: URL?

    /// Handles the actual export to file operation. During processing, it will also
    /// be queried for progress updates.
    private var exportSession: AVAssetExportSession?

    /// A timer to monitor export progress.
    private var timer: Timer?

    /// Export a movie clip to file.
    ///
    /// - Parameters:
    ///   - asset: The AVAsset containing the source movie.
    ///   - timeRange: The time range of the source movie to export.
    ///   - outputURL: The output URL for the exported file.
    func export(asset: AVAsset, timeRange: CMTimeRange, to outputURL: URL) {
        resetProgress()
        isExporting = true
        
        // Monitor progress while the export session is running
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let exportSession = self?.exportSession, exportSession.status == .exporting
            else { return }

            self?.progress = Double(exportSession.progress)
        }

        let uniformType = UTType(filenameExtension: outputURL.pathExtension) ?? .mpeg4Movie
        let outputFileType = AVFileType(rawValue: uniformType.identifier)

        Task {
            // Check the compatibility of the preset to export the video to the output file type.
            guard await AVAssetExportSession.compatibility(
                ofExportPreset: AVAssetExportPresetHighestQuality,
                with: asset,
                outputFileType: outputFileType
            ) else {
                DispatchQueue.main.async {
                    self.resetProgress(withError: ClipExportError.incompatibleOutputFileType(outputURL.pathExtension))
                }
                return
            }

            // Create and configure the export session.
            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                DispatchQueue.main.async {
                    self.resetProgress(withError: ClipExportError.invalidExportSession)
                }
                return
            }

            self.exportSession = exportSession

            let tempURL = URL(filePath: NSTemporaryDirectory())
                .appending(component: UUID().uuidString)
                .appendingPathExtension(outputURL.pathExtension)
            print(tempURL)

            // Convert the video to the output file type and export it to the output URL.
            exportSession.outputFileType = outputFileType
            exportSession.outputURL = tempURL
            exportSession.timeRange = timeRange

            await exportSession.export()

            // Move temporary file to its final location, overwriting any existsing file
            do {
                if FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)) {
                    try FileManager.default.removeItem(at: outputURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: outputURL)
            } catch {
                DispatchQueue.main.async {
                    self.resetProgress(withError: ClipExportError.internal(
                        "Failed to write file: \(error.localizedDescription)"
                    ))
                }

                return
            }

            DispatchQueue.main.async {
                if let errorDescription = exportSession.error?.localizedDescription {
                    self.resetProgress(withError: ClipExportError.internal(errorDescription))
                } else {
                    self.resetProgress()
                    self.lastExportURL = outputURL
                }
            }
        }
    }

    /// Ends processing and resets state, optionally setting an error.
    ///
    /// - Parameter clipExportError: The error if one occurred, or nil otherwise.
    private func resetProgress(withError clipExportError: ClipExportError? = nil) {
        exportSession?.cancelExport()
        timer?.invalidate()
        isExporting = false
        progress = 0
        error = clipExportError
    }

    /// Cancels current progress without reporting any errors.
    func cancel() { resetProgress() }
}
