import Foundation

//  NOTE (Anuson, 9/22): marked `id` (Anime, MalRef) and `displayTitle`
//  (Anime) `nonisolated`, and added a `nonisolated` convenience initializer
//  `Anime.init(malId:title:images:)` in an extension below. Same root cause
//  as the KitsuResource.swift fix: SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
//  makes every un-annotated computed property/initializer implicitly
//  @MainActor-isolated, and KitsuClient (its own actor) reads/constructs
//  these synchronously in map/filter/compactMap closures (see
//  KitsuClient.swift lines ~58, 111, 159-160 -- recommendations(animeId:)
//  in particular needed both the new initializer and `nonisolated` on it
//  and on `displayTitle` before it would compile). Aung -- please review.

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
    nonisolated var id: Int { malId }
 
    /// English title when we have one, otherwise the romanised title.
    nonisolated var displayTitle: String {
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
 
//  NOTE (Anuson, 9/22): added the init(malId:title:images:) convenience
//  initializer below. Root cause: KitsuClient.swift's recommendations(_:)
//  builds a lightweight RecommendationEntry.entry via
//  `.init(malId: $0.id, title: $0.displayTitle, images: $0.images)`, but
//  Anime had no matching 3-argument initializer -- only the full
//  ~29-argument memberwise one. Swift couldn't find a matching overload and
//  fell back to comparing against Decodable's `init(from:)`, which is why
//  Xcode reported the confusing "Missing argument for parameter 'from'" /
//  "Extra arguments at positions #1, #2, #3" pair at KitsuClient.swift:160
//  instead of a clear "no matching initializer" error. This was masked
//  until RecommendationEntry.swift existed for the compiler to check this
//  far. Put in an extension (not the main struct body) so the existing
//  full memberwise init KitsuResource.anime(in:) relies on keeps working.
//  Aung -- please review; let me know if the "Related anime" rail should
//  carry more fields than title + poster.
extension Anime {
    nonisolated init(malId: Int, title: String, images: AnimeImages) {
        self.init(malId: malId, url: nil, title: title, titleEnglish: nil, titleJapanese: nil,
            type: nil, source: nil, episodes: nil, status: nil, airing: nil, duration: nil,
            rating: nil, score: nil, scoredBy: nil, rank: nil, popularity: nil, members: nil,
            favorites: nil, synopsis: nil, background: nil, season: nil, year: nil, aired: nil,
            images: images, trailer: nil, genres: nil, themes: nil, demographics: nil,
            studios: nil, producers: nil)
    }
}

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
 
    nonisolated var id: Int { malId }
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
