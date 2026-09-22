//
//  CachedAsyncImage.swift
//  KiminoAnime
//
//  T4.5 — loads a poster/portrait through ImageCache (Storage layer,
//  T3.x) so scrolling never re-fetches the same image twice. Falls
//  back to a shimmer while loading and a photo glyph on failure.
//
//  NOTE: this depends on `ImageCache.shared` from Storage/ImageCache.swift
//  (Part 3, persistence layer). It will not compile until that file has
//  an actual implementation — that's a teammate's task, not a bug here.
//

import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    var cornerRadius: CGFloat = Theme.Radius.poster

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
        guard let url else { didFail = true; return }
        if let cached = await ImageCache.shared.image(for: url) {
            image = cached
            return
        }
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
            await ImageCache.shared.insert(decoded, for: url)
            image = decoded
        } catch {
            if !Task.isCancelled { didFail = true }
        }
    }
}
