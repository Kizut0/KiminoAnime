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
    private(set) var refreshError: APIError?
    private(set) var isRefreshing = false
    private(set) var genres: [MalRef] = []
    private(set) var genresError: APIError?
    var selectedGenreIds: Set<Int> = []
    var recents: [String] = RecentSearches.load()

    private var page = 1
    private var canLoadMore = true
    private var lastQuery = ""
    private var lastGenreIds: [Int] = []
    private var lastSafeOnly = true
    private var requestGeneration = UUID()

    func loadGenresIfNeeded() async {
        if genres.isEmpty,
           let cached = DiskCache.load("kitsu-genres-v1", as: [MalRef].self) {
            genres = cached
        }
        do {
            let response = try await KitsuClient.shared.animeGenres()
            genres = Array(response.data.prefix(24))
            DiskCache.save(genres, as: "kitsu-genres-v1")
            genresError = nil
        } catch let error as APIError {
            if genres.isEmpty && error != .cancelled { genresError = error }
        } catch {
            if genres.isEmpty { genresError = .badResponse }
        }
    }

    func search(_ query: String, safeOnly: Bool) async {
        let generation = UUID()
        requestGeneration = generation
        paginationError = nil
        refreshError = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let genreIds = selectedGenreIds.sorted()
        guard !trimmed.isEmpty || !selectedGenreIds.isEmpty else {
            state = .initial
            isRefreshing = false
            isLoadingMore = false
            return
        }
        lastQuery = trimmed
        lastGenreIds = genreIds
        lastSafeOnly = safeOnly
        page = 1
        canLoadMore = false
        isLoadingMore = false
        let cacheKey = OfflineCacheKey.search(trimmed, genres: genreIds, safeOnly: safeOnly)
        let cached = DiskCache.load(cacheKey, as: CachedAnimePage.self)
        if let cached {
            page = cached.page
            canLoadMore = cached.hasNextPage
            state = cached.items.isEmpty ? .empty(trimmed) : .results(cached.items)
        } else {
            state = .searching
        }
        isRefreshing = true
        defer {
            if generation == requestGeneration { isRefreshing = false }
        }
        do {
            let response = try await KitsuClient.shared.search(
                query: trimmed, page: 1,
                genreIds: genreIds, safeOnly: safeOnly
            )
            guard generation == requestGeneration, !Task.isCancelled else { return }
            page = 1
            canLoadMore = response.pagination?.hasNextPage ?? false
            refreshError = nil
            DiskCache.save(CachedAnimePage(items: response.data, page: 1, hasNextPage: canLoadMore), as: cacheKey)
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
            guard error != .cancelled else { return }
            if cached != nil { refreshError = error }
            else { state = .failed(error) }
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            if cached != nil { refreshError = .badResponse }
            else { state = .failed(.badResponse) }
        }
    }

    func loadMoreIfNeeded(current item: Anime, safeOnly: Bool) async {
        guard canLoadMore, !isLoadingMore, !isRefreshing,
              safeOnly == lastSafeOnly,
              selectedGenreIds.sorted() == lastGenreIds,
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
                genreIds: lastGenreIds, safeOnly: lastSafeOnly
            )
            guard generation == requestGeneration, !Task.isCancelled else { return }
            page += 1
            canLoadMore = response.pagination?.hasNextPage ?? false
            paginationError = nil
            let existing = Set(current.map(\.malId))
            let items = current + response.data.filter { !existing.contains($0.malId) }
            state = .results(items)
            DiskCache.save(
                CachedAnimePage(items: items, page: page, hasNextPage: canLoadMore),
                as: OfflineCacheKey.search(lastQuery, genres: lastGenreIds, safeOnly: lastSafeOnly)
            )
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
        refreshError = nil
        isRefreshing = false
        selectedGenreIds = []
        page = 1
        isLoadingMore = false
    }

    func clearRecents() {
        RecentSearches.clear()
        recents = []
    }
}
