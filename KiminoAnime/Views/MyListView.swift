import SwiftUI
import SwiftData

struct MyListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedAnime.dateAdded, order: .reverse) private var allSaved: [SavedAnime]
    @State private var filter: WatchStatus?
    @AppStorage(PrefKey.listSort) private var sortRaw = ListSort.dateAdded.rawValue

    private var sort: ListSort { ListSort(rawValue: sortRaw) ?? .dateAdded }
    private var visible: [SavedAnime] {
        let filtered = filter == nil ? allSaved : allSaved.filter { $0.status == filter }
        switch sort {
        case .dateAdded: return filtered
        case .title: return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .score: return filtered.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        case .progress: return filtered.sorted { $0.progress > $1.progress }
        }
    }

    var body: some View {
        NavigationStack {
            Group { if allSaved.isEmpty { emptyState } else { listContent } }
                .background(Theme.Colors.background)
                .navigationTitle("My List")
                .navigationDestination(for: Int.self) { DetailView(animeId: $0) }
                .navigationDestination(for: Anime.self) { DetailView(anime: $0) }
                .toolbar { sortMenu }
        }
        .task { await refreshMissingDetails() }
    }

    private func refreshMissingDetails() async {
        let store = LibraryStore(context: context)
        for saved in allSaved where saved.detailData == nil {
            guard !Task.isCancelled else { return }
            do {
                let result = try await KitsuClient.shared.animeDetail(id: saved.malId)
                guard !Task.isCancelled else { return }
                store.cacheDetail(result.data)
            } catch APIError.offline {
                return
            } catch is CancellationError {
                return
            } catch {
                // Another saved title may still refresh successfully.
                continue
            }
        }
    }
}

private extension MyListView {
    var listContent: some View {
        VStack(spacing: 0) {
            ListStatsBar(items: allSaved)
            filterBar
            if visible.isEmpty {
                EmptyStateView(title: "Nothing here yet", message: "You have no titles marked as “\(filter?.rawValue ?? "")”.", symbol: "line.3.horizontal.decrease.circle")
            } else {
                List {
                    ForEach(visible) { item in
                        NavigationLink {
                            // Open from the SwiftData snapshot so this route
                            // does not depend on the network or an ID lookup.
                            DetailView(anime: item.offlineAnime)
                        } label: {
                            SavedRow(item: item, context: context)
                        }
                            .listRowBackground(Theme.Colors.background)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { withAnimation(Motion.snappy) { LibraryStore(context: context).remove(item) } } label: { Label("Remove", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button { LibraryStore(context: context).setFavourite(!item.isFavourite, on: item) } label: { Label("Favourite", systemImage: item.isFavourite ? "heart.slash" : "heart") }.tint(.pink)
                            }
                    }
                }.listStyle(.plain).animation(Motion.snappy, value: visible.count)
            }
        }
    }

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                GenreChip(title: "All (\(allSaved.count))", isSelected: filter == nil) { withAnimation(Motion.snappy) { filter = nil } }
                ForEach(WatchStatus.allCases) { status in
                    let count = allSaved.filter { $0.status == status }.count
                    GenreChip(title: "\(status.rawValue) (\(count))", isSelected: filter == status) { withAnimation(Motion.snappy) { filter = status } }
                }
            }.padding(.horizontal, Theme.Space.screen).padding(.vertical, Theme.Space.sm)
        }
    }

    var emptyState: some View {
        EmptyStateView(title: "Your list is empty", message: "Find something on Discover and tap Add to My List. Your list is saved on this device and works offline.", symbol: "bookmark", actionTitle: "Browse Discover") {
            UserDefaults.standard.set(0, forKey: PrefKey.lastTab)
            NotificationCenter.default.post(name: .switchToDiscover, object: nil)
        }
    }

    var sortMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu { Picker("Sort by", selection: $sortRaw) { ForEach(ListSort.allCases) { Label($0.rawValue, systemImage: symbol(for: $0)).tag($0.rawValue) } } } label: { Image(systemName: "arrow.up.arrow.down.circle") }
                .accessibilityLabel("Sort saved anime")
        }
    }
    func symbol(for sort: ListSort) -> String { switch sort { case .dateAdded: "calendar"; case .title: "textformat"; case .score: "star"; case .progress: "chart.bar" } }
}

struct SavedRow: View {
    @Bindable var item: SavedAnime
    let context: ModelContext
    private var store: LibraryStore { LibraryStore(context: context) }
    var body: some View {
        HStack(spacing: Theme.Space.md) {
            CachedAsyncImage(
                url: item.posterURL,
                cachedData: item.posterData,
                onImageLoaded: { store.cachePoster($0, for: item.malId, url: item.posterURL) }
            )
            .frame(width: 58, height: 87)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(spacing: Theme.Space.xs) {
                    Text(item.title).font(Theme.Text.cardTitle).foregroundStyle(Theme.Colors.primary).lineLimit(2)
                    if item.isFavourite { Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.pink) }
                }
                Label(item.status.rawValue, systemImage: item.status.symbol).font(Theme.Text.meta).foregroundStyle(item.status.tint)
                ProgressView(value: item.progress).tint(Theme.Colors.accent)
                Text(item.progressLabel).font(.caption2).foregroundStyle(Theme.Colors.secondary).monospacedDigit().contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            VStack(spacing: Theme.Space.xs) {
                Button { withAnimation(Motion.quick) { store.setEpisodes(item.episodesWatched + 1, on: item) } } label: { Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Theme.Colors.accent) }.buttonStyle(.plain).sensoryFeedback(.increase, trigger: item.episodesWatched).accessibilityLabel("Add one episode")
                Button { withAnimation(Motion.quick) { store.setEpisodes(item.episodesWatched - 1, on: item) } } label: { Image(systemName: "minus.circle").font(.title3).foregroundStyle(Theme.Colors.secondary) }.buttonStyle(.plain).disabled(item.episodesWatched == 0).accessibilityLabel("Remove one episode")
            }
        }.padding(.vertical, Theme.Space.xs).accessibilityElement(children: .contain)
    }
}

struct ListStatsBar: View {
    let items: [SavedAnime]
    private var totalEpisodes: Int { items.reduce(0) { $0 + $1.episodesWatched } }
    private var averageScore: Double { let values = items.compactMap(\.score).filter { $0 > 0 }; return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
    private var completed: Int { items.filter { $0.status == .completed }.count }
    var body: some View {
        HStack(spacing: 0) {
            stat("\(items.count)", "Titles"); divider; stat("\(totalEpisodes)", "Episodes"); divider
            stat(averageScore > 0 ? String(format: "%.1f", averageScore) : "—", "Avg score"); divider; stat("\(completed)", "Completed")
        }.padding(.vertical, Theme.Space.md).background(Theme.Colors.card).clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card)).padding(.horizontal, Theme.Space.screen)
    }
    private func stat(_ value: String, _ label: String) -> some View { VStack(spacing: 2) { Text(value).font(.title3.weight(.bold)).monospacedDigit().contentTransition(.numericText()); Text(label).font(.caption2).foregroundStyle(Theme.Colors.secondary) }.frame(maxWidth: .infinity) }
    private var divider: some View { Rectangle().fill(Theme.Colors.divider).frame(width: 1, height: 26) }
}

extension Notification.Name { static let switchToDiscover = Notification.Name("switchToDiscover") }
