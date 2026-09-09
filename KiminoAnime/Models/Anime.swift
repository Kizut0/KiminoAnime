import Foundation
 
struct Anime: Codable, Identifiable, Hashable {
 
    // MARK: Identity
    // Preserve saved MAL IDs; negative ranges identify provider-only titles.
    let malId: Int
    var kitsuId: Int? = nil
    let url: String?
 
    // MARK: Titles
    let title: String
    let titleEnglish: String?
    let titleJapanese: String?
 
    // MARK: Classification
    let type: String?          // TV, Movie, OVA, Special, ONA, Music
    let source: String?        // Manga, Original, Light novel, Game...
    let episodes: Int?
    let status: String?        // "Finished Airing", "Currently Airing"...
    let airing: Bool?
    let duration: String?      // "24 min per ep"
    let rating: String?        // "PG-13 - Teens 13 or older"
 
    // MARK: Scores
    let score: Double?
    let scoredBy: Int?
    let rank: Int?
    let popularity: Int?
    let members: Int?
    let favorites: Int?
 
    // MARK: Text
    let synopsis: String?
    let background: String?
 
    // MARK: Dates
    let season: String?        // "spring", "summer", "fall", "winter"
    let year: Int?
    let aired: DateRange?
 
    // MARK: Media
    let images: AnimeImages
    let trailer: Trailer?
 
    // MARK: Relations
    let genres: [MalRef]?
    let themes: [MalRef]?
    let demographics: [MalRef]?
    let studios: [MalRef]?
    let producers: [MalRef]?
 
    // MARK: Derived
    var id: Int { malId }
 
    /// English title when we have one, otherwise the romanised title.
    var displayTitle: String {
        if let e = titleEnglish, !e.isEmpty { return e }
        return title
    }
 
    var posterURL: URL? {
        URL(string: images.jpg.largeImageUrl ?? images.jpg.imageUrl ?? "")
    }
 
    /// "TV · 2009 · 64 eps" — nil parts are dropped, no empty separators.
    var metaLine: String {
        var parts: [String] = []
        if let type { parts.append(type) }
        if let year { parts.append(String(year)) }
        if let episodes { parts.append("\(episodes) eps") }
        return parts.joined(separator: " · ")
    }
 
    var genreNames: [String] { (genres ?? []).map(\.name) }
 
    // Hashable / Equatable on identity only — cheap and correct for lists.
    static func == (lhs: Anime, rhs: Anime) -> Bool { lhs.malId == rhs.malId }
    func hash(into hasher: inout Hasher) { hasher.combine(malId) }
}
 
// MARK: - Sub-models
 
struct AnimeImages: Codable, Hashable {
    let jpg: ImageSet
 
    struct ImageSet: Codable, Hashable {
        let imageUrl: String?
        let smallImageUrl: String?
        let largeImageUrl: String?
    }
}
 
/// Used for genres, studios, producers, themes, demographics —
/// Retains the original persisted model shape for library compatibility.
struct MalRef: Codable, Hashable, Identifiable {
    let malId: Int
    let type: String?
    let name: String
    let url: String?
 
    var id: Int { malId }
}
 
struct DateRange: Codable, Hashable {
    let from: String?          // ISO 8601
    let to: String?
 
    var fromDate: Date? { from.flatMap { ISO8601DateFormatter().date(from: $0) } }
    var toDate: Date?   { to.flatMap   { ISO8601DateFormatter().date(from: $0) } }
}
 
struct Trailer: Codable, Hashable {
    let youtubeId: String?
    let url: String?
    let embedUrl: String?
}
