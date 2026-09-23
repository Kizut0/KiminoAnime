
import SwiftUI

@Observable
final class GenreAnimeViewModel {
    enum LoadState: Equatable {
        case loading
        case results([Anime])
        case empty
        case failed(APIError)
    }

    private(set) var state: LoadState = .loading
    private(set) var isLoadingMore = false
    private(set) var paginationError: APIError?
    private(set) var refreshError: APIError?
    private(set) var isRefreshing = false

    private var page = 1
    private var canLoadMore = true
    private var requestGeneration = UUID()
    private var activeGenreId: Int?
    private var activeSafeOnly: Bool?

    func load(genreId: Int, safeOnly: Bool) async {
        let generation = UUID()
        requestGeneration = generation
        activeGenreId = genreId
        activeSafeOnly = safeOnly
        page = 1
        canLoadMore = false
        isLoadingMore = false
        paginationError = nil
        refreshError = nil
        let cacheKey = OfflineCacheKey.genre(genreId, safeOnly: safeOnly)
        let cached = DiskCache.load(cacheKey, as: CachedAnimePage.self)
        if let cached {
            page = cached.page
            canLoadMore = cached.hasNextPage
            state = cached.items.isEmpty ? .empty : .results(cached.items)
        } else {
            state = .loading
        }
        isRefreshing = true
        defer {
            if generation == requestGeneration { isRefreshing = false }
        }
        do {
            let response = try await KitsuClient.shared.search(
                query: "", page: 1, genreIds: [genreId], safeOnly: safeOnly
            )
            guard generation == requestGeneration, !Task.isCancelled else { return }
            page = 1
            canLoadMore = response.pagination?.hasNextPage ?? false
            DiskCache.save(CachedAnimePage(items: response.data, page: 1, hasNextPage: canLoadMore), as: cacheKey)
            state = response.data.isEmpty ? .empty : .results(response.data)
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

    func loadMoreIfNeeded(current item: Anime, genreId: Int, safeOnly: Bool) async {
        guard canLoadMore, !isLoadingMore, !isRefreshing,
              activeGenreId == genreId, activeSafeOnly == safeOnly,
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
                query: "", page: page + 1, genreIds: [genreId], safeOnly: safeOnly
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
                as: OfflineCacheKey.genre(genreId, safeOnly: safeOnly)
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

    func retryLoadMore(genreId: Int, safeOnly: Bool) async {
        guard case .results(let current) = state,
              let last = current.last else { return }
        await loadMoreIfNeeded(
            current: last,
            genreId: genreId,
            safeOnly: safeOnly
        )
    }
}
