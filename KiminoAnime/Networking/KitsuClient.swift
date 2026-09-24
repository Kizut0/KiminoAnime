import Foundation

nonisolated struct AnimeSeason: Equatable {
    let year: Int
    let name: String

    static func current(at date: Date = .now) -> Self {
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        let name = ["winter", "spring", "summer", "fall"][(month - 1) / 3]
        return Self(year: year, name: name)
    }
}

actor KitsuClient {
    static let shared = KitsuClient()
    private let session: URLSession
    private var nextRequestAt = Date.distantPast
    private var identities: [Int: Int] = [:]
    private var genres: [MalRef] = []

    init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        self.session = session ?? URLSession(configuration: configuration)
    }

    func request<T: Decodable>(_ path: String, query: [URLQueryItem] = [], maxAttempts: Int = 3, timeout: TimeInterval = 20, as: T.Type) async throws -> T {
        #if DEBUG
        // Deterministic simulator check without changing the device or host network.
        if ProcessInfo.processInfo.arguments.contains("-KiminoAnimeForceOffline") {
            throw APIError.offline
        }
        #endif
        guard var components = URLComponents(string: "https://kitsu.app/api/edge/" + path) else { throw APIError.badURL }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.badURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        request.setValue("KiminoAnime/1.0", forHTTPHeaderField: "User-Agent")
        for attempt in 0..<maxAttempts {
            try Task.checkCancellation()
            let slot = max(Date(), nextRequestAt)
            nextRequestAt = slot.addingTimeInterval(0.4)
            if slot.timeIntervalSinceNow > 0 { try await Task.sleep(for: .seconds(slot.timeIntervalSinceNow)) }
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
                if http.statusCode == 429 || (500...599).contains(http.statusCode) {
                    guard attempt + 1 < maxAttempts else { throw http.statusCode == 429 ? APIError.rateLimited : APIError.server(http.statusCode) }
                    let delay = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? pow(2, Double(attempt + 1))
                    nextRequestAt = max(nextRequestAt, Date().addingTimeInterval(max(1, delay)))
                    continue
                }
                if http.statusCode == 404 { throw APIError.notFound }
                guard (200...299).contains(http.statusCode) else { throw APIError.server(http.statusCode) }
                do { return try JSONDecoder().decode(T.self, from: data) }
                catch { throw APIError.decoding(String(describing: error)) }
            } catch let error as URLError {
                switch error.code {
                case .cancelled: throw APIError.cancelled
                case .timedOut: if attempt + 1 == maxAttempts { throw APIError.server(408) }
                case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                     .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed: throw APIError.offline
                default: throw APIError.badResponse
                }
            } catch is CancellationError { throw APIError.cancelled }
        }
        throw APIError.badResponse
    }

    private func map(_ resources: [KitsuResource], included: [KitsuResource]) throws -> [Anime] {
        try resources.filter { $0.type == "anime" }.map {
            let anime = try $0.anime(in: included)
            identities[anime.id] = anime.kitsuId
            return anime
        }
    }

    private func page(_ page: Int, safeOnly: Bool, firstLoad: Bool = false, query: [URLQueryItem]) async throws -> AnimeResponse<[Anime]> {
        var items = query + [URLQueryItem(name: "page[limit]", value: "20"),
            .init(name: "page[offset]", value: String((max(1, page) - 1) * 20)),
            .init(name: "include", value: "mappings,categories")]
        if safeOnly { items.append(.init(name: "filter[ageRating]", value: "G,PG,R")) }
        let result = try await request("anime", query: items, maxAttempts: firstLoad ? 1 : 3,
            timeout: firstLoad ? 12 : 20, as: KitsuDocument<[KitsuResource]>.self)
        let data = try map(result.data, included: result.included ?? [])
        return AnimeResponse(data: data, pagination: result.pagination(page: page))
    }

    func topAnime(page: Int = 1, safeOnly: Bool = true) async throws -> AnimeResponse<[Anime]> {
        try await self.page(page, safeOnly: safeOnly, firstLoad: page == 1, query: [.init(name: "sort", value: "-averageRating")])
    }

    func currentSeason(page: Int = 1, safeOnly: Bool = true, season: AnimeSeason = .current()) async throws -> AnimeResponse<[Anime]> {
        return try await self.page(page, safeOnly: safeOnly, firstLoad: true, query: [
            .init(name: "filter[season]", value: season.name), .init(name: "filter[seasonYear]", value: String(season.year)),
            .init(name: "sort", value: "-userCount")])
    }

    func animeGenres() async throws -> AnimeResponse<[MalRef]> {
        if genres.isEmpty {
            let result = try await request("categories", query: [.init(name: "sort", value: "-totalMediaCount"),
                .init(name: "page[limit]", value: "20")], as: KitsuDocument<[KitsuResource]>.self)
            genres = result.data.compactMap(\.category).sorted { $0.name < $1.name }
        }
        return AnimeResponse(data: genres, pagination: nil)
    }

    func search(query text: String, page: Int = 1, genreIds: [Int] = [], minScore: Double? = nil,
                safeOnly: Bool = true) async throws -> AnimeResponse<[Anime]> {
        var items: [URLQueryItem] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { items.append(.init(name: "filter[text]", value: trimmed)) }
        else { items.append(.init(name: "sort", value: "-userCount")) }
        if !genreIds.isEmpty {
            var available = try await animeGenres().data
            // Detail pages include categories beyond the popular genre bar.
            // Resolve those IDs rather than silently dropping their filter.
            for id in genreIds where !available.contains(where: { $0.id == id }) {
                let result = try await request("categories/\(id)", as: KitsuDocument<KitsuResource>.self)
                guard let category = result.data.category, category.type != nil else { throw APIError.notFound }
                available.append(category)
                genres.append(category)
            }
            let categories = available.filter { genreIds.contains($0.id) }.compactMap(\.type)
            guard !categories.isEmpty else { throw APIError.notFound }
            items.append(.init(name: "filter[categories]", value: categories.joined(separator: ",")))
        }
        if let minScore { items.append(.init(name: "filter[averageRating]", value: "\(minScore * 10),100")) }
        return try await self.page(page, safeOnly: safeOnly, query: items)
    }

    private func kitsuID(for id: Int) async throws -> Int {
        if let cached = identities[id] { return cached }
        if id <= -KitsuResource.identityOffset { return -id - KitsuResource.identityOffset }
        let site = id > 0 ? "myanimelist/anime" : "anilist/anime"
        let result = try await request("mappings", query: [.init(name: "filter[externalSite]", value: site),
            .init(name: "filter[externalId]", value: String(abs(id))), .init(name: "include", value: "item")],
            as: KitsuDocument<[KitsuResource]>.self)
        guard let resource = result.included?.first(where: { $0.type == "anime" }), let kitsu = Int(resource.id) else { throw APIError.notFound }
        identities[id] = kitsu
        return kitsu
    }

    func animeDetail(id: Int) async throws -> AnimeResponse<Anime> {
        let kitsu = try await kitsuID(for: id)
        let result = try await request("anime/\(kitsu)", query: [.init(name: "include", value: "mappings,categories")],
            as: KitsuDocument<KitsuResource>.self)
        let anime = try map([result.data], included: result.included ?? [])[0]
        return AnimeResponse(data: anime, pagination: nil)
    }

    func characters(animeId: Int) async throws -> AnimeResponse<[AnimeCharacterEntry]> {
        let kitsu = try await kitsuID(for: animeId)
        let result = try await request("anime/\(kitsu)/characters", query: [.init(name: "include", value: "character"),
            .init(name: "sort", value: "role"), .init(name: "page[limit]", value: "15")], as: KitsuDocument<[KitsuResource]>.self)
        return AnimeResponse(data: result.data.compactMap { $0.character(in: result.included ?? []) }, pagination: nil)
    }

    func recommendations(animeId: Int) async throws -> AnimeResponse<[RecommendationEntry]> {
        let kitsu = try await kitsuID(for: animeId)
        let result = try await request("anime/\(kitsu)/media-relationships", query: [.init(name: "include", value: "destination"),
            .init(name: "page[limit]", value: "10")], as: KitsuDocument<[KitsuResource]>.self)
        let included = result.included ?? []
        let resources = result.data.flatMap { $0.related("destination", in: included) }.filter { $0.type == "anime" }
        guard !resources.isEmpty else { return AnimeResponse(data: [], pagination: nil) }
        let titles = try await request("anime", query: [
            .init(name: "filter[id]", value: resources.map(\.id).joined(separator: ",")),
            .init(name: "include", value: "mappings,categories"), .init(name: "page[limit]", value: "20")],
            as: KitsuDocument<[KitsuResource]>.self)
        let anime = try map(titles.data, included: titles.included ?? [])
        var seen: Set<Int> = []
        return AnimeResponse(data: anime.filter { seen.insert($0.id).inserted }.map {
            RecommendationEntry(entry: .init(malId: $0.id, title: $0.displayTitle, images: $0.images), votes: nil)
        }, pagination: nil)
    }
}
