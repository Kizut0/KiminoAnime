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
                VStack(spacing: 0) {
                    refreshStatus
                    EmptyStateView(
                        title: "No results",
                        message: "Nothing found for \(genre.name) right now.",
                        symbol: "sparkle.magnifyingglass"
                    )
                }
            case .results(let items):
                VStack(spacing: 0) {
                    refreshStatus
                    resultsGrid(items)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(genre.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: safeSearch) {
            await vm.load(genreId: genre.malId, safeOnly: safeSearch)
        }
    }

    @ViewBuilder
    private var refreshStatus: some View {
        if let error = vm.refreshError {
            InlineRetryRow(title: "Couldn't update \(genre.name) anime", error: error, isLoading: vm.isRefreshing) {
                await vm.load(genreId: genre.malId, safeOnly: safeSearch)
            }
            .padding(.vertical, Theme.Space.sm)
        } else if vm.isRefreshing {
            ProgressView("Updating saved results…")
                .font(Theme.Text.meta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.sm)
        }
    }

    private func resultsGrid(_ items: [Anime]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Space.lg) {
                ForEach(items) { anime in
                    NavigationLink(value: anime) {
                        PosterCard(anime: anime)
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
            } else if let error = vm.paginationError {
                PaginationRetryRow(error: error, isLoading: vm.isLoadingMore) {
                    await vm.retryLoadMore(
                        genreId: genre.malId,
                        safeOnly: safeSearch
                    )
                }
            }
        }
    }
}
