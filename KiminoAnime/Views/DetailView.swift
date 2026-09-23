import SwiftUI
import SwiftData

struct DetailView: View {
    let seed: Anime?
    let animeId: Int
    @State private var vm = DetailViewModel()
    @State private var showFullSynopsis = false
    @State private var showStatusPicker = false
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    init(anime: Anime) { seed = anime; animeId = anime.malId }
    init(animeId: Int) { seed = nil; self.animeId = animeId }

    private var availableAnime: Anime? {
        let saved = store.entry(for: animeId)
        if let saved, saved.detailData != nil { return saved.offlineAnime }
        return DiskCache.load(OfflineCacheKey.detail(animeId), as: Anime.self)
            ?? saved?.offlineAnime ?? seed
    }

    private func refreshDetails() async {
        let saved = store.entry(for: animeId)
        if let saved, saved.detailData == nil,
           let cached = DiskCache.load(OfflineCacheKey.detail(animeId), as: Anime.self) {
            store.cacheDetail(cached)
        }
        await vm.load(
            seed: vm.anime ?? availableAnime,
            id: animeId,
            cachedCharacters: saved?.charactersData != nil
                ? (saved?.offlineCharacters ?? [])
                : (DiskCache.load(OfflineCacheKey.characters(animeId), as: [AnimeCharacterEntry].self) ?? []),
            cachedRecommendations: saved?.recommendationsData != nil
                ? (saved?.offlineRecommendations ?? [])
                : (DiskCache.load(OfflineCacheKey.recommendations(animeId), as: [RecommendationEntry].self) ?? []),
            onDetailLoaded: {
                DiskCache.save($0, as: OfflineCacheKey.detail(animeId))
                store.cacheDetail($0)
            },
            onCharactersLoaded: {
                DiskCache.save($0, as: OfflineCacheKey.characters(animeId))
                store.cacheCharacters($0, for: animeId)
            },
            onRecommendationsLoaded: {
                DiskCache.save($0, as: OfflineCacheKey.recommendations(animeId))
                store.cacheRecommendations($0, for: animeId)
            }
        )
    }

    var body: some View {
        Group {
            // Any saved title can render from SwiftData, including routes
            // that navigate by ID rather than from a My List row.
            if let anime = vm.anime ?? availableAnime { content(anime) }
            else if let error = vm.error { ErrorStateView(error: error) { await refreshDetails() } }
            else { LoadingStateView() }
        }
        .background(Theme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await refreshDetails() }
    }

    private func content(_ anime: Anime) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(anime)
                if let error = vm.error {
                    InlineRetryRow(
                        title: "Couldn't refresh details",
                        error: error,
                        isLoading: vm.isLoading
                    ) {
                        await refreshDetails()
                    }
                    .padding(.top, Theme.Space.md)
                }
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    statsRow(anime)
                    actionButton(anime)
                    genresSection(anime)
                    synopsisSection(anime)
                    charactersSection(animeId: anime.malId)
                    recommendationsSection(animeId: anime.malId)
                }
                .padding(.top, Theme.Space.xl)
                .padding(.bottom, Theme.Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.background)
            }
        }
        .coordinateSpace(name: "detailScroll")
        .ignoresSafeArea(edges: .top)
        .navigationDestination(for: Int.self) { DetailView(animeId: $0) }
    }

    private func header(_ anime: Anime) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("detailScroll")).minY
            let stretch = systemReduceMotion ? 0 : max(0, minY)
            CachedAsyncImage(
                url: anime.posterURL,
                cornerRadius: 0,
                cachedData: store.entry(for: anime.malId)?.posterData,
                onImageLoaded: { store.cachePoster($0, for: anime.malId, url: anime.posterURL) }
            )
                .frame(width: geo.size.width, height: 460 + stretch)
                .clipped()
                .posterScrim()
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text(anime.displayTitle).font(.title.weight(.bold)).foregroundStyle(.white)
                        if let japanese = anime.titleJapanese { Text(japanese).font(.subheadline).foregroundStyle(.white.opacity(0.75)) }
                    }
                    .padding(Theme.Space.screen).padding(.bottom, Theme.Space.sm)
                }
                // Move the artwork and caption together so the bottom edge
                // remains above the statistics even while pulling down.
                .offset(y: -stretch)
                .accessibilityLabel(anime.displayTitle)
        }
        .frame(height: 460)
    }
}

private extension DetailView {
    var store: LibraryStore { LibraryStore(context: context) }

    func statsRow(_ anime: Anime) -> some View {
        HStack(spacing: Theme.Space.xl) {
            if let score = anime.score, score > 0 { ScoreRing(score: score, reduceMotion: systemReduceMotion) }
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                if let rank = anime.rank { StatLine(symbol: "trophy.fill", label: "Ranked", value: "#\(rank)") }
                if let popularity = anime.popularity { StatLine(symbol: "flame.fill", label: "Popularity", value: "#\(popularity)") }
                if let members = anime.members { StatLine(symbol: "person.2.fill", label: "Members", value: members.formatted(.number.notation(.compactName))) }
                if let status = anime.status { StatLine(symbol: "dot.radiowaves.left.and.right", label: "Status", value: status) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.screen)
    }

    func actionButton(_ anime: Anime) -> some View {
        let saved = store.entry(for: anime.malId)
        return VStack(spacing: Theme.Space.md) {
            Button {
                if saved != nil { withAnimation(Motion.snappy) { store.remove(malId: anime.malId) } }
                else { showStatusPicker = true }
            } label: {
                Label(saved == nil ? "Add to My List" : "In My List", systemImage: saved == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, Theme.Space.md)
                    .background(saved == nil ? Theme.Colors.accent : Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .foregroundStyle(saved == nil ? Color.white : Theme.Colors.primary)
                    .overlay { RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(saved == nil ? Color.clear : Theme.Colors.accent, lineWidth: 1.5) }
            }
            .sensoryFeedback(.success, trigger: saved != nil)
            if let saved {
                Picker("Status", selection: Binding(get: { saved.status }, set: { store.setStatus($0, on: saved) })) {
                    ForEach(WatchStatus.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, Theme.Space.screen)
        .confirmationDialog("Add to My List", isPresented: $showStatusPicker, titleVisibility: .visible) {
            ForEach(WatchStatus.allCases) { status in
                Button(status.rawValue) {
                    withAnimation(Motion.snappy) { _ = store.add(anime, status: status) }
                    if vm.hasFreshDetail || DiskCache.load(OfflineCacheKey.detail(anime.malId), as: Anime.self) != nil {
                        store.cacheDetail(anime)
                    }
                    if !vm.characters.isEmpty { store.cacheCharacters(vm.characters, for: anime.malId) }
                    if !vm.recommendations.isEmpty { store.cacheRecommendations(vm.recommendations, for: anime.malId) }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    func genresSection(_ anime: Anime) -> some View {
        Group {
            if let genres = anime.genres, !genres.isEmpty {
                FlowLayout(spacing: Theme.Space.sm) {
                    ForEach(genres) { genre in
                        if genre.malId < 0 {
                            GenreChip(title: genre.name)
                        } else {
                            NavigationLink {
                                GenreAnimeView(genre: genre)
                            } label: {
                                GenreChip(title: genre.name)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Browse \(genre.name) anime")
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.screen)
            }
        }
    }

    func synopsisSection(_ anime: Anime) -> some View {
        Group {
            if let synopsis = anime.synopsis, !synopsis.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    SectionHeader(title: "Synopsis")
                    Text(synopsis).font(Theme.Text.body).foregroundStyle(Theme.Colors.primary).lineLimit(showFullSynopsis ? nil : 5).padding(.horizontal, Theme.Space.screen)
                    Button(showFullSynopsis ? "Show less" : "Show more") { withAnimation(Motion.gentle) { showFullSynopsis.toggle() } }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.Colors.accent).padding(.horizontal, Theme.Space.screen)
                }
            }
        }
    }

    @ViewBuilder
    func charactersSection(animeId: Int) -> some View {
        if !vm.characters.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionHeader(title: "Characters")
                if let error = vm.charactersError {
                    InlineRetryRow(
                        title: "Couldn't refresh characters",
                        error: error,
                        isLoading: vm.isLoadingCharacters
                    ) {
                        await vm.retryCharacters(animeId: animeId) {
                            DiskCache.save($0, as: OfflineCacheKey.characters(animeId))
                            store.cacheCharacters($0, for: animeId)
                        }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: Theme.Space.md) {
                        ForEach(vm.characters) { entry in
                            VStack(spacing: Theme.Space.sm) {
                                CachedAsyncImage(url: entry.character.portraitURL, cornerRadius: 40).frame(width: 80, height: 80)
                                Text(entry.character.name).font(.caption.weight(.medium)).lineLimit(2).multilineTextAlignment(.center)
                                if let role = entry.role { Text(role).font(.caption2).foregroundStyle(Theme.Colors.secondary) }
                            }.frame(width: 92)
                        }
                    }.padding(.horizontal, Theme.Space.screen)
                }
            }
        } else if vm.isLoadingCharacters {
            ProgressView("Loading characters…")
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Space.screen)
        } else if let error = vm.charactersError {
            InlineRetryRow(
                title: "Couldn't load characters",
                error: error,
                isLoading: vm.isLoadingCharacters
            ) {
                await vm.retryCharacters(animeId: animeId) {
                    DiskCache.save($0, as: OfflineCacheKey.characters(animeId))
                    store.cacheCharacters($0, for: animeId)
                }
            }
        }
    }

    @ViewBuilder
    func recommendationsSection(animeId: Int) -> some View {
        if !vm.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionHeader(title: "Related anime")
                if let error = vm.recommendationsError {
                    InlineRetryRow(
                        title: "Couldn't refresh related anime",
                        error: error,
                        isLoading: vm.isLoadingRecommendations
                    ) {
                        await vm.retryRecommendations(animeId: animeId) {
                            DiskCache.save($0, as: OfflineCacheKey.recommendations(animeId))
                            store.cacheRecommendations($0, for: animeId)
                        }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.Space.md) {
                        ForEach(vm.recommendations) { rec in
                            NavigationLink(value: rec.entry.malId) {
                                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                                    CachedAsyncImage(url: rec.entry.posterURL).frame(width: 110, height: 165)
                                    Text(rec.entry.title).font(.caption.weight(.medium)).foregroundStyle(Theme.Colors.primary).lineLimit(2).frame(width: 110, alignment: .leading)
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, Theme.Space.screen)
                }
            }
        } else if vm.isLoadingRecommendations {
            ProgressView("Loading related anime…")
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Space.screen)
        } else if let error = vm.recommendationsError {
            InlineRetryRow(
                title: "Couldn't load related anime",
                error: error,
                isLoading: vm.isLoadingRecommendations
            ) {
                await vm.retryRecommendations(animeId: animeId) {
                    DiskCache.save($0, as: OfflineCacheKey.recommendations(animeId))
                    store.cacheRecommendations($0, for: animeId)
                }
            }
        }
    }
}

struct StatLine: View {
    let symbol: String; let label: String; let value: String
    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: symbol).font(.caption).foregroundStyle(Theme.Colors.accent).frame(width: 16)
                .accessibilityHidden(true)
            Text(label).font(Theme.Text.meta).foregroundStyle(Theme.Colors.secondary)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(Theme.Colors.primary)
        }
        // T11.3: read as one sentence ("Ranked, #12") instead of three fragments.
        .accessibilityElement(children: .combine)
    }
}
