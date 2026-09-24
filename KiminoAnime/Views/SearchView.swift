import SwiftUI

struct SearchView: View {
    @State private var vm = SearchViewModel()
    @State private var query = ""
    @AppStorage(PrefKey.safeSearch) private var safeSearch = true
    @Namespace private var zoom

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                genreBar
                Group {
                    switch vm.state {
                    case .initial: initialState
                    case .searching: LoadingStateView(message: "Searching…")
                    case .empty(let term):
                        VStack(spacing: 0) {
                            refreshStatus
                            EmptyStateView(title: "No results", message: "Nothing matched “\(term)”. Try a shorter or differently spelled title.", symbol: "magnifyingglass")
                        }
                    case .failed(let error): ErrorStateView(error: error) { await vm.search(query, safeOnly: safeSearch) }
                    case .results(let items):
                        VStack(spacing: 0) {
                            refreshStatus
                            resultsList(items)
                        }
                    }
                }
                .animation(Motion.quick, value: vm.state)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Search")
            .navigationDestination(for: Anime.self) { anime in
                DetailView(anime: anime).navigationTransition(.zoom(sourceID: anime.malId, in: zoom))
            }
            .navigationDestination(for: Int.self) { DetailView(animeId: $0) }
        }
        .task { await vm.loadGenresIfNeeded() }
        .onChange(of: safeSearch) { _, value in
            Task { await vm.search(query, safeOnly: value) }
        }
        .task(id: query) {
            guard !query.isEmpty else {
                if vm.selectedGenreIds.isEmpty {
                    vm.clear()
                } else {
                    await vm.search(query, safeOnly: safeSearch)
                }
                return
            }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await vm.search(query, safeOnly: safeSearch)
        }
    }
}

private extension SearchView {
    var searchField: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.secondary)
                .accessibilityHidden(true)

            TextField("Search 25,000+ titles", text: $query)
                .font(Theme.Text.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { Task { await vm.search(query, safeOnly: safeSearch) } }
                .accessibilityLabel("Search anime by title")

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .frame(minHeight: 44)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        }
        .padding(.horizontal, Theme.Space.screen)
        .padding(.top, Theme.Space.sm)
    }

    @ViewBuilder
    var refreshStatus: some View {
        if let error = vm.refreshError {
            InlineRetryRow(title: "Couldn't update search results", error: error, isLoading: vm.isRefreshing) {
                await vm.search(query, safeOnly: safeSearch)
            }
            .padding(.vertical, Theme.Space.sm)
        } else if vm.isRefreshing {
            ProgressView("Updating saved results…")
                .font(Theme.Text.meta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.sm)
        }
    }

    var genreBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                ForEach(vm.genres) { genre in
                    GenreChip(title: genre.name, isSelected: vm.selectedGenreIds.contains(genre.malId)) { toggle(genre) }
                }
                if vm.genres.isEmpty, vm.genresError != nil {
                    Label("Genres unavailable offline", systemImage: "wifi.slash")
                        .font(Theme.Text.meta)
                        .foregroundStyle(Theme.Colors.secondary)
                    Button("Try again") { Task { await vm.loadGenresIfNeeded() } }
                        .font(Theme.Text.meta)
                }
            }
            .padding(.horizontal, Theme.Space.screen)
            .padding(.vertical, Theme.Space.sm)
        }
    }

    func toggle(_ genre: MalRef) {
        if vm.selectedGenreIds.contains(genre.malId) { vm.selectedGenreIds.remove(genre.malId) }
        else { vm.selectedGenreIds.insert(genre.malId) }
        Task { await vm.search(query, safeOnly: safeSearch) }
    }

    var initialState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                if !vm.recents.isEmpty {
                    HStack {
                        SectionHeader(title: "Recent")
                        Spacer()
                        Button("Clear") { vm.clearRecents() }.padding(.trailing, Theme.Space.screen)
                    }
                    VStack(spacing: 0) {
                        ForEach(vm.recents, id: \.self) { term in
                            Button { query = term } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.Colors.secondary)
                                        .accessibilityHidden(true)
                                    Text(term).foregroundStyle(Theme.Colors.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(Theme.Colors.secondary)
                                        .accessibilityHidden(true)
                                }
                                .padding(.vertical, Theme.Space.md).padding(.horizontal, Theme.Space.screen)
                            }
                            Divider().padding(.leading, Theme.Space.screen)
                        }
                    }
                } else {
                    EmptyStateView(title: "Find something to watch", message: "Search by title, or pick a genre above.", symbol: "sparkle.magnifyingglass").frame(minHeight: 320)
                }
            }
            .padding(.top, Theme.Space.md)
        }
    }

    func resultsList(_ items: [Anime]) -> some View {
        List {
            ForEach(items) { anime in
                NavigationLink(value: anime) { SearchResultRow(anime: anime) }
                    .listRowBackground(Theme.Colors.background)
                    .matchedTransitionSource(id: anime.malId, in: zoom)
                    .task { await vm.loadMoreIfNeeded(current: anime, safeOnly: safeSearch) }
            }
            if vm.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Theme.Colors.background)
            } else if let error = vm.paginationError {
                PaginationRetryRow(error: error, isLoading: vm.isLoadingMore) {
                    await vm.retryLoadMore(safeOnly: safeSearch)
                }
                .listRowBackground(Theme.Colors.background)
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
    }
}

struct SearchResultRow: View {
    let anime: Anime
    var body: some View {
        HStack(spacing: Theme.Space.md) {
            CachedAsyncImage(url: anime.posterURL).frame(width: 56, height: 84)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(anime.displayTitle).font(Theme.Text.cardTitle).foregroundStyle(Theme.Colors.primary).lineLimit(2)
                if !anime.metaLine.isEmpty { Text(anime.metaLine).font(Theme.Text.meta).foregroundStyle(Theme.Colors.secondary) }
                if let score = anime.score, score > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                        Text(String(format: "%.2f", score)).font(.caption.weight(.semibold)).monospacedDigit()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .combine)
    }
}
