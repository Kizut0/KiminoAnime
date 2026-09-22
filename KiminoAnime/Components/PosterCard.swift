//
//  PosterCard.swift
//  KiminoAnime
//
//  T4.6 — used by Discover, Search results and the Detail
//  recommendations row. The fixed height on the title is deliberate:
//  without it, one-line and two-line titles produce ragged grids.
//

import SwiftUI

struct PosterCard: View {
    let anime: Anime
    var width: CGFloat = 150
    var showsScore: Bool = true

    private var height: CGFloat { width / Theme.posterAspect }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: anime.posterURL)
                    .frame(width: width, height: height)
                if showsScore, let score = anime.score, score > 0 {
                    ScoreBadge(score: score)
                        .padding(Theme.Space.sm)
                }
            }
            Text(anime.displayTitle)
                .font(Theme.Text.cardTitle)
                .foregroundStyle(Theme.Colors.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(height: 34, alignment: .top)
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
