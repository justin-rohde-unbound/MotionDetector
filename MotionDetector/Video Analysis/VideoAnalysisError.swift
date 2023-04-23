import SwiftUI

/// Errors that can occur when extracting and comparing video still frames.
enum VideoAnalysisError: Error, Identifiable {
    case invalidVideoTrack
    case frameAnalysis(_ reason: String)
    case cancelled

    var id: String { description }

    var description: String {
        switch self {
        case .cancelled: return "The operation was cancelled by the user."
        case .frameAnalysis(let reason): return "Unable to analyze frame: \(reason)"
        case .invalidVideoTrack: return "Unable to load video data."
        }
    }
}
