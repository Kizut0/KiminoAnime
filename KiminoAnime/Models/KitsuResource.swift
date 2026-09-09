import Foundation

struct KitsuDocument<T: Decodable>: Decodable {
    let data: T
    let included: [KitsuResource]?
    let links: Links?
    struct Links: Decodable { let next: String? }

    func pagination(page: Int) -> Pagination {
        let hasNext = links?.next != nil
        return Pagination(lastVisiblePage: page + (hasNext ? 1 : 0), hasNextPage: hasNext, items: nil)
    }
}

/// JSON:API resources share a common envelope. Related resources are resolved
/// by both type and ID; numeric IDs alone are not unique across resource types.
struct KitsuResource: Decodable {
    let id: String
    let type: String
    let attributes: Attributes
    let relationships: [String: Relationship]?

    struct Attributes: Decodable {
        let canonicalTitle: String?
        let titles: [String: String?]?
        let synopsis: String?
        let subtype: String?
        let status: String?
        let averageRating: String?
        let userCount: Int?
        let favoritesCount: Int?
        let ratingRank: Int?
        let popularityRank: Int?
        let startDate: String?
        let endDate: String?
        let ageRating: String?
        let ageRatingGuide: String?
        let episodeCount: Int?
        let episodeLength: Int?
        let posterImage: Images?
        let youtubeVideoId: String?
        let nsfw: Bool?
        // Categories, ID mappings, characters, and production relationships.
        let title: String?
        let slug: String?
        let externalSite: String?
        let externalId: String?
        let role: String?
        let canonicalName: String?
        let name: String?
        let image: Images?
    }
    struct Images: Decodable {
        let tiny: String?
        let small: String?
        let medium: String?
        let large: String?
        let original: String?
    }
    struct Reference: Decodable { let id: String; let type: String }
    struct Relationship: Decodable {
        let data: References?
    }
    enum References: Decodable {
        case one(Reference), many([Reference])
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let array = try? container.decode([Reference].self) { self = .many(array) }
            else { self = .one(try container.decode(Reference.self)) }
        }
        var values: [Reference] {
            switch self { case .one(let value): [value]; case .many(let values): values }
        }
    }

    func related(_ name: String, in included: [KitsuResource]) -> [KitsuResource] {
        (relationships?[name]?.data?.values ?? []).compactMap { reference in
            included.first { $0.id == reference.id && $0.type == reference.type }
        }
    }

    // Positive IDs remain compatible with existing MAL-based My List records.
    // Reserve a separate negative range from the previous AniList-only IDs.
    static let identityOffset = 1_000_000_000
    func anime(in included: [KitsuResource]) throws -> Anime {
        guard type == "anime", let kitsuID = Int(id) else { throw APIError.badResponse }
        let malID = related("mappings", in: included).first {
            $0.attributes.externalSite == "myanimelist/anime"
        }?.attributes.externalId.flatMap(Int.init)
        let a = attributes
        let titles = a.titles?.compactMapValues { $0 } ?? [:]
        let start = a.startDate?.split(separator: "-")
        let month = start.flatMap { $0.count > 1 ? Int($0[1]) : nil }
        let season = month.flatMap { (1...12).contains($0) ? ["winter", "spring", "summer", "fall"][($0 - 1) / 3] : nil }
        let trailerID = a.youtubeVideoId.flatMap { $0.isEmpty ? nil : $0 }
        let studios = related("productions", in: included).flatMap { $0.related("producer", in: included) }
        var anime = Anime(
            malId: malID ?? -(Self.identityOffset + kitsuID), url: "https://kitsu.app/anime/\(id)",
            title: a.canonicalTitle ?? titles["en_jp"] ?? "Untitled",
            titleEnglish: titles["en"] ?? titles["en_us"], titleJapanese: titles["ja_jp"],
            type: a.subtype?.uppercased(), source: nil, episodes: a.episodeCount,
            status: a.status.map { ["finished": "Finished Airing", "current": "Currently Airing", "upcoming": "Not yet aired", "unreleased": "Not yet aired"][$0] ?? $0.capitalized },
            airing: a.status == "current", duration: a.episodeLength.map { "\($0) min per ep" },
            rating: a.ageRatingGuide ?? a.ageRating,
            score: a.averageRating.flatMap(Double.init).map { $0 / 10 }, scoredBy: nil,
            rank: a.ratingRank, popularity: a.popularityRank, members: a.userCount, favorites: a.favoritesCount,
            synopsis: a.synopsis, background: nil, season: season,
            year: start?.first.flatMap { Int($0) },
            aired: DateRange(from: a.startDate.map { $0 + "T00:00:00Z" }, to: a.endDate.map { $0 + "T00:00:00Z" }),
            images: AnimeImages(jpg: .init(imageUrl: a.posterImage?.medium ?? a.posterImage?.large,
                smallImageUrl: a.posterImage?.small, largeImageUrl: a.posterImage?.large ?? a.posterImage?.original)),
            trailer: trailerID.map { Trailer(youtubeId: $0, url: "https://www.youtube.com/watch?v=\($0)", embedUrl: "https://www.youtube.com/embed/\($0)") },
            genres: related("categories", in: included).compactMap { $0.category }, themes: nil, demographics: nil,
            studios: studios.compactMap { resource in
                guard let id = Int(resource.id), let name = resource.attributes.name else { return nil }
                return MalRef(malId: id, type: nil, name: name, url: nil)
            }, producers: nil)
        anime.kitsuId = kitsuID
        return anime
    }

    var category: MalRef? {
        guard type == "categories", let id = Int(id), let title = attributes.title else { return nil }
        return MalRef(malId: id, type: attributes.slug, name: title, url: nil)
    }

    func character(in included: [KitsuResource]) -> AnimeCharacterEntry? {
        guard let character = related("character", in: included).first, let id = Int(character.id) else { return nil }
        let a = character.attributes
        return AnimeCharacterEntry(character: .init(malId: id, name: a.canonicalName ?? a.name ?? "Unknown",
            images: .init(jpg: .init(imageUrl: a.image?.large ?? a.image?.original, smallImageUrl: a.image?.small))),
            role: attributes.role?.capitalized, favorites: nil, voiceActors: nil)
    }
}
