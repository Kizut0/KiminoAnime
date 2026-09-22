//
//  GenreAnimeView.swift
//  KiminoAnime
//
//  Created by Aung Myat Oo Gyaw on 9/9/26.
//
//  NOTE (Anuson, 9/22): this file was empty -- no `struct` at all -- and it
//  was blocking the whole build, since DetailView.swift's genre chips push
//  into it (genresSection(_:), `NavigationLink { GenreAnimeView(genre:
//  genre) }`). Built as a genre-filtered results grid, reusing the same
//  PosterCard / LazyVGrid layout as DiscoverView's "Top Rated" section and
//  the same LoadingStateView/ErrorStateView/EmptyStateView pattern as
//  SearchView. It pushes further taps with `NavigationLink(value: anime)`
//  rather than declaring its own navigationDestination(for: Anime.self) --
//  it's always pushed from inside a NavigationStack that already registers
//  that destination (Discover, Search, or My List), so it resolves there.
//  Aung -- please review; happy to adjust styling/behavior to match what
//  you had in mind for this screen.
//

import SwiftUI

struct GenreAnimeView: View {
    let genre: MalRef

    @State private var vm = GenreAnimeViewModel()
    @AppStorage(PrefKey.safeSearch) private var safeSearch = true

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Space.md),
        GridItem(.flexible(), spacing: Theme.Space.md)
    ]

    var body: some View {
        Group {
            switch vm.state {
            case .loading:
                LoadingStateView(message: "Finding \(genre.name) anime…")
            case .failed(let error):
                ErrorStateView(error: error) {
                    await vm.load(genreId: genre.malId, safeOnly: safeSearch)
                }
            case .empty:
                EmptyStateView(
                    title: "No results",
                    message: "Nothing found for \(genre.name) right now.",
                    symbol: "sparkle.magnifyingglass"
                )
            case .results(let items):
                resultsGrid(items)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(genre.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(genreId: genre.malId, safeOnly: safeSearch) }
    }

    private func resultsGrid(_ items: [Anime]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Space.lg) {
                ForEach(items) { anime in
                    NavigationLink(value: anime) {
                        PosterCard(anime: anime, width: 165)
                    }
                    .buttonStyle(.plain)
                    .task { await vm.loadMoreIfNeeded(current: anime, genreId: genre.malId, safeOnly: safeSearch) }
                }
            }
            .padding(Theme.Space.screen)

            if vm.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.lg)
            }
        }
    }
}
