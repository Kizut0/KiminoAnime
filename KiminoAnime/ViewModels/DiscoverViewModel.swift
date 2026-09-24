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
    private(set) var paginationError: APIError?

    private var page = 1
    private var canLoadMore = false
    private var activeFilter: Bool?
    private var activeSeason: AnimeSeason?
    private var generation = UUID()
    private let topCacheKey = "top"
    private let seasonalLoader: (Bool, AnimeSeason) async throws -> AnimeResponse<[Anime]>
    private let topLoader: (Int, Bool) async throws -> AnimeResponse<[Anime]>
    private let readCache: (String) -> [Anime]?
    private let saveCache: ([Anime], String) -> Void

    init(
        seasonalLoader: @escaping (Bool, AnimeSeason) async throws -> AnimeResponse<[Anime]> = {
            try await KitsuClient.shared.currentSeason(safeOnly: $0, season: $1)
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
    private func seasonalCacheKey(safeOnly: Bool, season: AnimeSeason) -> String {
        "kitsu-\(safeOnly)-seasonal-\(season.year)-\(season.name)"
    }

    private func cachedSeasonal(safeOnly: Bool, season: AnimeSeason) -> [Anime]? {
        let key = seasonalCacheKey(safeOnly: safeOnly, season: season)
        if let cached = readCache(key) { return cached }

        // Older app versions used a seasonless key. Reuse it only when every
        // title confirms that it belongs to the current season.
        guard let legacy = readCache("kitsu-\(safeOnly)-seasonal"),
              !legacy.isEmpty,
              legacy.allSatisfy({ $0.season == season.name && $0.year == season.year })
        else { return nil }
        saveCache(legacy, key)
        return legacy
    }

    func load(safeOnly: Bool) async {
        let season = AnimeSeason.current()
        guard !isRefreshing || activeFilter != safeOnly || activeSeason != season else { return }
        let token = UUID()
        generation = token
        let changedFilter = activeFilter != safeOnly
        let changedSeason = activeSeason != season
        let shouldReloadCachedContent = changedFilter || !hasContent
        activeFilter = safeOnly
        activeSeason = season
        isRefreshing = true
        refreshError = nil
        paginationError = nil
        isLoadingMore = false
        canLoadMore = false

        // Render saved results before starting any network work. Keep current
        // content during manual refresh, but never mix content-safety filters.
        if shouldReloadCachedContent || changedSeason {
            seasonal = cachedSeasonal(safeOnly: safeOnly, season: season) ?? []
        }
        if shouldReloadCachedContent {
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
        async let seasonalRequest: Void = updateSeason(safeOnly: safeOnly, season: season, token: token)
        async let rated: Void = updateTop(safeOnly: safeOnly, token: token)
        _ = await (seasonalRequest, rated)
        guard generation == token, !Task.isCancelled else { return }
        isShowingCached = hasContent && refreshError != nil
    }

    private func updateSeason(safeOnly: Bool, season: AnimeSeason, token: UUID) async {
        do {
            let response = try await seasonalLoader(safeOnly, season)
            guard generation == token, !Task.isCancelled else { return }
            seasonal = response.data
            saveCache(seasonal, seasonalCacheKey(safeOnly: safeOnly, season: season))
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
        paginationError = nil

        defer {
            if generation == token {
                isLoadingMore = false
            }
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
            paginationError = nil

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
            guard generation == token, !Task.isCancelled else { return }

            guard error != .cancelled else {
                return
            }

            paginationError = error

        } catch {
            guard generation == token, !Task.isCancelled else { return }
            paginationError = .badResponse
        }
    }

    func retryLoadMore(safeOnly: Bool) async {
        guard let last = top.last else { return }
        await loadMoreIfNeeded(current: last, safeOnly: safeOnly)
    }

    func refresh(safeOnly: Bool) async {
        await load(safeOnly: safeOnly)
    }

    func refreshSeasonIfNeeded(safeOnly: Bool) async {
        guard activeSeason != AnimeSeason.current() else { return }
        await load(safeOnly: safeOnly)
    }
}
