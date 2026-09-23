import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    var cornerRadius: CGFloat = Theme.Radius.poster
    var cachedData: Data? = nil
    var onImageLoaded: ((Data) -> Void)? = nil

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else if didFail {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.Colors.divider.opacity(0.5))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.secondary)
                    }
            } else {
                ShimmerView(cornerRadius: cornerRadius)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .animation(Motion.quick, value: image != nil)
        .task(id: url) { await load() }
    }

    private func load() async {
        image = nil
        didFail = false
        if let cachedData, let decoded = UIImage(data: cachedData) {
            image = decoded
            return
        }
        guard let url else { didFail = true; return }
        if let cached = await ImageCache.shared.image(for: url) {
            image = cached
            if let onImageLoaded,
               let data = cached.jpegData(compressionQuality: 0.85) {
                onImageLoaded(data)
            }
            return
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-KiminoAnimeForceOffline") {
            didFail = true
            return
        }
        #endif
        do {
            // Plain URLSession — poster images come from the CDN and
            // must NOT go through the API client's own throttle, or
            // the grid would load one image every fraction of a second.
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }
            guard let decoded = UIImage(data: data) else {
                didFail = true
                return
            }
            await ImageCache.shared.insert(decoded, for: url, data: data)
            image = decoded
            onImageLoaded?(data)
        } catch {
            if !Task.isCancelled { didFail = true }
        }
    }
}
