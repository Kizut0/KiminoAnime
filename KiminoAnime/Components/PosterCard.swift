import SwiftUI

struct PosterCard: View {
    let anime: Anime
    var width: CGFloat?
    var showsScore: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: anime.posterURL)
                    .frame(maxWidth: .infinity)
                if showsScore, let score = anime.score, score > 0 {
                    ScoreBadge(score: score)
                        .padding(Theme.Space.sm)
                }
            }
            .aspectRatio(Theme.posterAspect, contentMode: .fit)
            Text(anime.displayTitle)
                .font(Theme.Text.cardTitle)
                .foregroundStyle(Theme.Colors.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 34, alignment: .top)
            if !anime.metaLine.isEmpty {
                Text(anime.metaLine)
                    .font(Theme.Text.meta)
                    .foregroundStyle(Theme.Colors.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = anime.displayTitle
        if let score = anime.score, score > 0 {
            text += ", rated \(String(format: "%.1f", score)) out of 10"
        }
        if !anime.metaLine.isEmpty { text += ", \(anime.metaLine)" }
        return text
    }
}

struct ScoreBadge: View {
    let score: Double
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 9))
            Text(String(format: "%.1f", score))
                .font(.caption2.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.65), in: Capsule())
    }
}
