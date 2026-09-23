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

    private var page = 1
    private var canLoadMore = true

    func load(genreId: Int, safeOnly: Bool) async {
        page = 1
        canLoadMore = true
        state = .loading
        do {
            let response = try await KitsuClient.shared.search(
                query: "", page: 1, genreIds: [genreId], safeOnly: safeOnly
            )
            canLoadMore = response.pagination?.hasNextPage ?? false
            state = response.data.isEmpty ? .empty : .results(response.data)
        } catch let error as APIError {
            if error != .cancelled { state = .failed(error) }
        } catch {
            state = .failed(.badResponse)
        }
    }

    func loadMoreIfNeeded(current item: Anime, genreId: Int, safeOnly: Bool) async {
        guard canLoadMore, !isLoadingMore,
              case .results(let current) = state,
              current.last?.malId == item.malId else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await KitsuClient.shared.search(
                query: "", page: page + 1, genreIds: [genreId], safeOnly: safeOnly
            )
            guard !Task.isCancelled else { return }
            page += 1
            canLoadMore = response.pagination?.hasNextPage ?? false
            let existing = Set(current.map(\.malId))
            state = .results(current + response.data.filter { !existing.contains($0.malId) })
        } catch let error as APIError {
            guard !Task.isCancelled, error != .cancelled else { return }
            canLoadMore = false
        } catch is CancellationError {
            return
        } catch {
            canLoadMore = false
        }
    }
}
