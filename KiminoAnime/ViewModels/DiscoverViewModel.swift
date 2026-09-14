import SwiftUI
import Observation

@MainActor
@Observable
final class DiscoverViewModel {
    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(APIError)
    }

    private(set) var state: LoadState = .idle
    private(set) var seasonal: [Anime] = []
    private(set) var top: [Anime] = []
    private(set) var isShowingCached = false
    private(set) var isRefreshing = false
    private(set) var refreshError: APIError?
    private(set) var isLoadingMore = false

    private var page = 1
    private var canLoadMore = false
    private var activeFilter: Bool?
    private var generation = UUID()
    private let seasonalCacheKey = "seasonal"
    private let topCacheKey = "top"
    private let seasonalLoader: (Bool) async throws -> AnimeResponse<[Anime]>
    private let topLoader: (Int, Bool) async throws -> AnimeResponse<[Anime]>
    private let readCache: (String) -> [Anime]?
    private let saveCache: ([Anime], String) -> Void

    init(
        seasonalLoader: @escaping (Bool) async throws -> AnimeResponse<[Anime]> = {
            try await KitsuClient.shared.currentSeason(safeOnly: $0)
        },
        topLoader: @escaping (Int, Bool) async throws -> AnimeResponse<[Anime]> = {
            try await KitsuClient.shared.topAnime(page: $0, safeOnly: $1)
        },
        readCache: @escaping (String) -> [Anime]? = { DiskCache.load($0, as: [Anime].self) },
        saveCache: @escaping ([Anime], String) -> Void = { DiskCache.save($0, as: $1) }
    ) {
        self.seasonalLoader = seasonalLoader
        self.topLoader = topLoader
        self.readCache = readCache
        self.saveCache = saveCache
    }

    var hero: Anime? { seasonal.first }
    private var hasContent: Bool { !seasonal.isEmpty || !top.isEmpty }

    func load(safeOnly: Bool) async {
        guard !isRefreshing || activeFilter != safeOnly else { return }
        let token = UUID()
        generation = token
        let changedFilter = activeFilter != safeOnly
        activeFilter = safeOnly
        isRefreshing = true
        refreshError = nil
        canLoadMore = false

        // Render saved results before starting any network work. Keep current
        // content during manual refresh, but never mix content-safety filters.
        if changedFilter || !hasContent {
            seasonal = readCache("kitsu-\(safeOnly)-" + seasonalCacheKey) ?? []
            top = readCache("kitsu-\(safeOnly)-" + topCacheKey) ?? []
        }
        isShowingCached = hasContent
        state = hasContent ? .loaded : .loading
        defer {
            if generation == token {
                isRefreshing = false
                if Task.isCancelled {
                    state = hasContent ? .loaded : .idle
                } else if !hasContent {
                    state = .failed(refreshError ?? .badResponse)
                }
            }
        }

        // Each child publishes its section immediately on completion; neither
        // section waits for the other to finish or fail.
        async let season: Void = updateSeason(safeOnly: safeOnly, token: token)
        async let rated: Void = updateTop(safeOnly: safeOnly, token: token)
        _ = await (season, rated)
        guard generation == token, !Task.isCancelled else { return }
        isShowingCached = hasContent && refreshError != nil
    }

    private func updateSeason(safeOnly: Bool, token: UUID) async {
        do {
            let response = try await seasonalLoader(safeOnly)
            guard generation == token, !Task.isCancelled else { return }
            seasonal = response.data
            saveCache(seasonal, "kitsu-\(safeOnly)-" + seasonalCacheKey)
            if hasContent { state = .loaded }
        } catch {
            record(error, token: token)
        }
    }

    private func updateTop(safeOnly: Bool, token: UUID) async {
        do {
            let response = try await topLoader(1, safeOnly)
            guard generation == token, !Task.isCancelled else { return }
            top = response.data
            page = 1
            canLoadMore = response.pagination?.hasNextPage ?? false
            saveCache(top, "kitsu-\(safeOnly)-" + topCacheKey)
            if hasContent { state = .loaded }
        } catch {
            record(error, token: token)
        }
    }

    private func record(_ error: Error, token: UUID) {
        guard generation == token, !Task.isCancelled else { return }
        refreshError = (error as? APIError) ?? .badResponse
    }

    // MARK: - Pagination

    func loadMoreIfNeeded(
        current item: Anime,
        safeOnly: Bool
    ) async {

        guard !isRefreshing,
              activeFilter == safeOnly,
              canLoadMore,
              !isLoadingMore,
              let last = top.last,
              last.malId == item.malId
        else {
            return
        }

        let token = generation
        isLoadingMore = true

        defer {
            isLoadingMore = false
        }

        do {

            let response =
                try await topLoader(page + 1, safeOnly)

            guard generation == token, !Task.isCancelled else {
                return
            }

            page += 1

            canLoadMore =
                response
                .pagination?
                .hasNextPage
                ?? false

            // Prevent duplicate ForEach IDs if Kitsu
            // repeats an anime across page boundaries.
            let existing =
                Set(
                    top.map(\.malId)
                )

            let newItems =
                response.data.filter {
                    !existing.contains(
                        $0.malId
                    )
                }

            top.append(
                contentsOf: newItems
            )

            // Keep cache fresh as pagination grows.
            saveCache(top, "kitsu-\(safeOnly)-" + topCacheKey)

        } catch let error as APIError {
            guard generation == token else { return }

            guard error != .cancelled else {
                return
            }

            // Fail pagination quietly.
            // Existing screen remains usable.
            canLoadMore = false

            #if DEBUG
            print(
                "Discover pagination failed:",
                error.localizedDescription
            )
            #endif

        } catch {
            guard generation == token else { return }

            canLoadMore = false

            #if DEBUG
            print(
                "Discover pagination failed:",
                error.localizedDescription
            )
            #endif
        }
    }

    func refresh(safeOnly: Bool) async {
        await load(safeOnly: safeOnly)
    }
}
