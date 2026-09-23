import Foundation
import SwiftData

extension Notification.Name {
    static let libraryStoreSaveFailed = Notification.Name("libraryStoreSaveFailed")
}

/// All writes to the watchlist go through here.
/// Views own a ModelContext; this owns the logic.
struct LibraryStore {

    let context: ModelContext

    // MARK: Queries

    func entry(for malId: Int) -> SavedAnime? {
        // #Predicate cannot capture a property path — bind to a local first.
        let target = malId

        var descriptor = FetchDescriptor<SavedAnime>(
            predicate: #Predicate { $0.malId == target }
        )

        descriptor.fetchLimit = 1

        return try? context.fetch(descriptor).first
    }

    func isSaved(_ malId: Int) -> Bool {
        entry(for: malId) != nil
    }

    func count() -> Int {
        (try? context.fetchCount(
            FetchDescriptor<SavedAnime>()
        )) ?? 0
    }

    // MARK: Mutations

    @discardableResult
    func add(
        _ anime: Anime,
        status: WatchStatus = .planToWatch
    ) -> SavedAnime {

        if let existing = entry(for: anime.malId) {
            existing.status = status
            save()
            return existing
        }

        let new = SavedAnime(
            from: anime,
            status: status
        )

        context.insert(new)
        save()

        return new
    }

    func remove(_ anime: SavedAnime) {
        context.delete(anime)
        save()
    }

    func remove(malId: Int) {
        if let existing = entry(for: malId) {
            remove(existing)
        }
    }

    func toggle(
        _ anime: Anime,
        status: WatchStatus = .planToWatch
    ) {
        if let existing = entry(for: anime.malId) {
            remove(existing)
        } else {
            add(anime, status: status)
        }
    }

    func setStatus(
        _ status: WatchStatus,
        on anime: SavedAnime
    ) {
        anime.status = status
        save()
    }

    func setFavourite(
        _ isFavourite: Bool,
        on anime: SavedAnime
    ) {
        anime.isFavourite = isFavourite
        anime.dateUpdated = .now
        save()
    }

    func setEpisodes(
        _ count: Int,
        on anime: SavedAnime
    ) {
        let nonNegativeCount = max(0, count)
        anime.episodesWatched = if let total = anime.totalEpisodes {
            min(nonNegativeCount, max(0, total))
        } else {
            nonNegativeCount
        }

        if let total = anime.totalEpisodes,
           anime.episodesWatched >= total {
            anime.status = .completed
        }

        anime.dateUpdated = .now
        save()
    }

    /// Keep server-owned fields current without changing watch progress.
    func cacheDetail(_ anime: Anime) {
        guard let saved = entry(for: anime.malId),
              let encoded = try? JSONEncoder().encode(anime)
        else { return }

        let nextPosterURL = anime.images.jpg.largeImageUrl
            ?? anime.images.jpg.imageUrl
        if saved.imageUrl != nextPosterURL { saved.posterData = nil }
        saved.detailData = encoded
        saved.title = anime.displayTitle
        saved.imageUrl = nextPosterURL
        saved.score = anime.score
        saved.type = anime.type
        saved.year = anime.year
        saved.totalEpisodes = anime.episodes
        if let total = anime.episodes {
            saved.episodesWatched = min(saved.episodesWatched, max(0, total))
        }
        saved.genreNames = anime.genreNames
        save()
    }

    func cacheCharacters(_ characters: [AnimeCharacterEntry], for malId: Int) {
        guard let saved = entry(for: malId),
              let encoded = try? JSONEncoder().encode(characters)
        else { return }
        saved.charactersData = encoded
        save()
    }

    func cacheRecommendations(_ recommendations: [RecommendationEntry], for malId: Int) {
        guard let saved = entry(for: malId),
              let encoded = try? JSONEncoder().encode(recommendations)
        else { return }
        saved.recommendationsData = encoded
        save()
    }

    func cachePoster(_ data: Data, for malId: Int, url: URL?) {
        guard let saved = entry(for: malId),
              saved.posterURL == url,
              saved.posterData == nil,
              data.count <= 4_000_000
        else { return }
        saved.posterData = data
        save()
    }

    func removeAll() {
        do {
            try context.delete(model: SavedAnime.self)
            save()
        } catch {
            reportSaveFailure(error)
        }
    }

    // MARK: Save

    /// SwiftData autosaves, but calling save() explicitly after a mutation
    /// removes all doubt on demo day and costs nothing.
    private func save() {
        do {
            try context.save()
        } catch {
            reportSaveFailure(error)
        }
    }

    private func reportSaveFailure(_ error: Error) {
        NotificationCenter.default.post(
            name: .libraryStoreSaveFailed,
            object: error.localizedDescription
        )

        #if DEBUG
        print("SwiftData save failed:", error)
        #endif
    }
}
