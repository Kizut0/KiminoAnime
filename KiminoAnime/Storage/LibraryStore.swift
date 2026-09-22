import Foundation
import SwiftData

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

    func setEpisodes(
        _ count: Int,
        on anime: SavedAnime
    ) {
        anime.episodesWatched = max(0, count)

        if let total = anime.totalEpisodes,
           anime.episodesWatched >= total {
            anime.status = .completed
        }

        anime.dateUpdated = .now
        save()
    }

    func removeAll() {
        try? context.delete(model: SavedAnime.self)
        save()
    }

    // MARK: Save

    /// SwiftData autosaves, but calling save() explicitly after a mutation
    /// removes all doubt on demo day and costs nothing.
    private func save() {
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("SwiftData save failed:", error)
            #endif
        }
    }
}
