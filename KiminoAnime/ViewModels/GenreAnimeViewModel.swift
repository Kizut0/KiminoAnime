//
//  GenreAnimeViewModel.swift
//  KiminoAnime
//
//  NOTE (Anuson, 9/22): new file -- GenreAnimeView.swift was completely
//  empty (just the Xcode header, no `struct` at all), and DetailView.swift's
//  genre chips push into it, so the build couldn't compile without it.
//  This is Aung's Detail-screen territory (genre -> filtered results), so
//  I modeled it closely on his own SearchViewModel.swift: same state enum
//  shape, same pagination pattern, same use of
//  KitsuClient.search(query:page:genreIds:safeOnly:) with an empty query
//  string and one genre ID (that's the exact "browse by genre with no
//  text" path SearchView already exercises when you tap a genre chip with
//  an empty search field, so it's a proven call, not a new one).
//  Aung -- please review and fold this into your part if you'd rather it
//  look different.
//

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

    private var page = 1
    private var canLoadMore = true
    private var requestGeneration = UUID()

    func load(genreId: Int, safeOnly: Bool) async {
        let generation = UUID()
        requestGeneration = generation
        page = 1
        canLoadMore = true
        isLoadingMore = false
        paginationError = nil
        state = .loading
        do {
            let response = try await KitsuClient.shared.search(
                query: "", page: 1, genreIds: [genreId], safeOnly: safeOnly
            )
            guard generation == requestGeneration, !Task.isCancelled else { return }
            canLoadMore = response.pagination?.hasNextPage ?? false
            state = response.data.isEmpty ? .empty : .results(response.data)
        } catch let error as APIError {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            if error != .cancelled { state = .failed(error) }
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            state = .failed(.badResponse)
        }
    }

    func loadMoreIfNeeded(current item: Anime, genreId: Int, safeOnly: Bool) async {
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
                query: "", page: page + 1, genreIds: [genreId], safeOnly: safeOnly
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
