import SwiftUI
import CoreMedia

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
//
//struct ImageCache {
//    static var cache = [CMTime: NSImage]()
//
//    func image(forTime time: CMTime) -> NSImage? {
//        Self.cache[time]
//    }
//
//    func setImage(_ image: NSImage, forTime: CMTime) {
//        Self.cache[time] = image
//    }
//}

// struct CachedImage {}

struct ThumbnailStrip: View {
    /// Generates thumbnails for the current video.
    @StateObject private var thumbnailGenerator = ThumbnailGenerator()

    /// The current size of the view, tracked to generate the number of thumbnails needed to fill the view.
    @StateObject private var size: Debounced<CGSize> = Debounced(delay: 0.25)

    /// The URL of the video from which to extract thumbnails.
    @Binding var videoURL: URL?

    var body: some View {
        GeometryReader { geometry in
            HStack {
                ForEach(thumbnailGenerator.thumbnails, id: \.self) { thumbnail in
                    Image(nsImage: thumbnail)
                }
            }
            .clipShape(Rectangle().size(geometry.size))
            .preference(key: SizePreferenceKey.self, value: geometry.size)
        }
        .onPreferenceChange(SizePreferenceKey.self) { size in
            self.size.input = size
        }
        .onChange(of: videoURL) { videoURL in
            refreshThumbnails(for: videoURL)
        }
        .onChange(of: size.value) { size in
            refreshThumbnails(for: videoURL)
        }
    }

    /// Generates new thumbnails to fit the current view size.
    ///
    /// - Parameter url: The URL of the video from which to extract thumbnails.
    private func refreshThumbnails(`for` url: URL?) {
        if let videoURL = videoURL, let size = size.value {
            thumbnailGenerator.generateThumbnails(
                fromURL: videoURL,
                forContainerSize: size
            )
        }
    }
}
