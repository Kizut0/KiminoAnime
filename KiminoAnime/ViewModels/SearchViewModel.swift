import SwiftUI

@Observable
final class SearchViewModel {
    enum SearchState: Equatable {
        case initial
        case searching
        case results([Anime])
        case empty(String)
        case failed(APIError)
    }

    private(set) var state: SearchState = .initial
    private(set) var isLoadingMore = false
    private(set) var paginationError: APIError?
    private(set) var genres: [MalRef] = []
    var selectedGenreIds: Set<Int> = []
    var recents: [String] = RecentSearches.load()

    private var page = 1
    private var canLoadMore = true
    private var lastQuery = ""
    private var requestGeneration = UUID()

    func loadGenresIfNeeded() async {
        guard genres.isEmpty else { return }
        if let cached = DiskCache.load("kitsu-genres-v1", as: [MalRef].self) {
            genres = cached
            return
        }
        if let response = try? await KitsuClient.shared.animeGenres() {
            genres = Array(response.data.prefix(24))
            DiskCache.save(genres, as: "kitsu-genres-v1")
        }
    }

    func search(_ query: String, safeOnly: Bool) async {
        let generation = UUID()
        requestGeneration = generation
        paginationError = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !selectedGenreIds.isEmpty else {
            state = .initial
            return
        }
        lastQuery = trimmed
        page = 1
        canLoadMore = true
        isLoadingMore = false
        state = .searching
        do {
            let response = try await KitsuClient.shared.search(
                query: trimmed, page: 1,
                genreIds: Array(selectedGenreIds), safeOnly: safeOnly
            )
            guard generation == requestGeneration, !Task.isCancelled else { return }
            canLoadMore = response.pagination?.hasNextPage ?? false
            if response.data.isEmpty {
                state = .empty(trimmed)
            } else {
                state = .results(response.data)
                if !trimmed.isEmpty {
                    RecentSearches.add(trimmed)
                    recents = RecentSearches.load()
                }
            }
        } catch let error as APIError {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            if error != .cancelled { state = .failed(error) }
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            state = .failed(.badResponse)
        }
    }

    func loadMoreIfNeeded(current item: Anime, safeOnly: Bool) async {
        guard canLoadMore, !isLoadingMore,
              case .results(let current) = state,
              current.last?.malId == item.malId else { return }
        let generation = requestGeneration
        isLoadingMore = true
        paginationError = nil
        defer {
            if generation == requestGeneration {
                isLoadingMore = false
            }
        }
        do {
            let response = try await KitsuClient.shared.search(
                query: lastQuery, page: page + 1,
                genreIds: Array(selectedGenreIds), safeOnly: safeOnly
            )
            guard generation == requestGeneration, !Task.isCancelled else { return }
            page += 1
            canLoadMore = response.pagination?.hasNextPage ?? false
            paginationError = nil
            let existing = Set(current.map(\.malId))
            state = .results(current + response.data.filter { !existing.contains($0.malId) })
        } catch let error as APIError {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            guard error != .cancelled else { return }
            paginationError = error
        } catch is CancellationError {
            return
        } catch {
            guard generation == requestGeneration else { return }
            paginationError = .badResponse
        }
    }

    func retryLoadMore(safeOnly: Bool) async {
        guard case .results(let current) = state,
              let last = current.last else { return }
        await loadMoreIfNeeded(current: last, safeOnly: safeOnly)
    }

    func clear() {
        requestGeneration = UUID()
        state = .initial
        paginationError = nil
        selectedGenreIds = []
        page = 1
        isLoadingMore = false
    }

    func clearRecents() {
        RecentSearches.clear()
        recents = []
    }
}
