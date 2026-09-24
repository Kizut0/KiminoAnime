import Foundation
import SwiftData
import SwiftUI

// MARK: - Watch Status

enum WatchStatus: String, Codable, CaseIterable, Identifiable {
    case watching    = "Watching"
    case completed   = "Completed"
    case planToWatch = "Plan to Watch"
    case dropped     = "Dropped"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .watching:
            "play.circle.fill"
        case .completed:
            "checkmark.circle.fill"
        case .planToWatch:
            "clock.fill"
        case .dropped:
            "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .watching:
            .blue
        case .completed:
            .green
        case .planToWatch:
            .orange
        case .dropped:
            .secondary
        }
    }
}


// MARK: - Saved Anime

@Model
final class SavedAnime {

    // MARK: Identity

    /// Unique so the same anime cannot be stored twice.
    @Attribute(.unique)
    var malId: Int

    // MARK: Offline Snapshot

    /// Denormalised data so My List can render without network access.
    var title: String
    var imageUrl: String?
    var score: Double?
    var type: String?
    var year: Int?
    var totalEpisodes: Int?
    var genreNames: [String]
    /// Last successful API detail and supporting sections. Optional fields
    /// keep existing SwiftData libraries readable after the app updates.
    var detailData: Data?
    var charactersData: Data?
    var recommendationsData: Data?
    var posterData: Data?

    // MARK: User Data

    var episodesWatched: Int
    var statusRaw: String
    var isFavourite: Bool
    var note: String
    var dateAdded: Date
    var dateUpdated: Date

    // MARK: Computed Properties

    var status: WatchStatus {
        get {
            WatchStatus(rawValue: statusRaw) ?? .planToWatch
        }
        set {
            statusRaw = newValue.rawValue
            dateUpdated = .now
        }
    }

    var posterURL: URL? {
        imageUrl.flatMap(URL.init(string:))
    }

    /// Value between 0 and 1 for a progress bar.
    /// Returns zero when the total episode count is unknown.
    var progress: Double {
        guard let total = totalEpisodes, total > 0 else {
            return 0
        }

        return min(
            Double(episodesWatched) / Double(total),
            1
        )
    }

    var progressLabel: String {
        if let total = totalEpisodes {
            return "\(episodesWatched) / \(total)"
        }

        return "\(episodesWatched) episodes"
    }

    // MARK: Initializer

    init(
        from anime: Anime,
        status: WatchStatus = .planToWatch
    ) {
        self.malId = anime.malId
        self.title = anime.displayTitle

        self.imageUrl =
            anime.images.jpg.largeImageUrl
            ?? anime.images.jpg.imageUrl

        self.score = anime.score
        self.type = anime.type
        self.year = anime.year
        self.totalEpisodes = anime.episodes
        self.genreNames = anime.genreNames
        self.detailData = nil
        self.charactersData = nil
        self.recommendationsData = nil
        self.posterData = nil

        self.episodesWatched = 0
        self.statusRaw = status.rawValue
        self.isFavourite = false
        self.note = ""
        self.dateAdded = .now
        self.dateUpdated = .now
    }
}

// MARK: - Offline detail snapshot

@MainActor
extension SavedAnime {
    var decodedDetail: Anime? {
        guard let detailData,
              let anime = try? JSONDecoder().decode(Anime.self, from: detailData),
              anime.malId == malId
        else { return nil }
        return anime
    }

    /// Prefer the last full API response; older records still have the
    /// original summary fields until they can be refreshed online.
    var offlineAnime: Anime {
        if let decodedDetail { return decodedDetail }

        let imageSet = AnimeImages.ImageSet(
            imageUrl: imageUrl,
            smallImageUrl: imageUrl,
            largeImageUrl: imageUrl
        )

        return Anime(
            malId: malId,
            url: nil,
            title: title,
            titleEnglish: nil,
            titleJapanese: nil,
            type: type,
            source: nil,
            episodes: totalEpisodes,
            status: nil,
            airing: nil,
            duration: nil,
            rating: nil,
            score: score,
            scoredBy: nil,
            rank: nil,
            popularity: nil,
            members: nil,
            favorites: nil,
            synopsis: nil,
            background: nil,
            season: nil,
            year: year,
            aired: nil,
            images: AnimeImages(jpg: imageSet),
            trailer: nil,
            genres: genreNames.enumerated().map { index, name in
                MalRef(malId: -(index + 1), type: "genres", name: name, url: nil)
            },
            themes: nil,
            demographics: nil,
            studios: nil,
            producers: nil
        )
    }

    var offlineCharacters: [AnimeCharacterEntry] {
        guard let charactersData else { return [] }
        return (try? JSONDecoder().decode([AnimeCharacterEntry].self, from: charactersData)) ?? []
    }

    var offlineRecommendations: [RecommendationEntry] {
        guard let recommendationsData else { return [] }
        return (try? JSONDecoder().decode([RecommendationEntry].self, from: recommendationsData)) ?? []
    }
}
