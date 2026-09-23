import SwiftUI

private struct DiscoverHeroOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DiscoverView: View {

    // MARK: - View Model

    @State private var vm =
        DiscoverViewModel()

    // MARK: - Preferences

    @AppStorage(PrefKey.safeSearch)
    private var safeSearch = true

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    // MARK: - Navigation Transition

    @Namespace private var zoom

    // MARK: - Stagger Animation

    @State private var appeared:
        Set<Int> = []

    @State private var heroOffset: CGFloat = 0

    private var heroHasScrolled: Bool {
        heroOffset < -8
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            Group {

                switch vm.state {

                case .idle,
                     .loading:

                    LoadingStateView(
                        message:
                            "Finding good anime…"
                    )

                case .failed(let error):

                    ErrorStateView(
                        error: error
                    ) {

                        await vm.load(
                            safeOnly:
                                safeSearch
                        )
                    }

                case .loaded:

                    content
                }
            }
            .onPreferenceChange(DiscoverHeroOffsetKey.self) {
                heroOffset = $0
            }
            .background(
                Theme
                    .Colors
                    .background
            )
            .navigationTitle(
                "Discover"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                vm.hero == nil || heroHasScrolled ? .visible : .hidden,
                for: .navigationBar
            )
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarColorScheme(
                vm.hero == nil || heroHasScrolled ? nil : .dark,
                for: .navigationBar
            )
            .navigationDestination(
                for: Anime.self
            ) { anime in

                DetailView(
                    anime: anime
                )
                .navigationTransition(
                    .zoom(
                        sourceID:
                            anime.malId,
                        in: zoom
                    )
                )
            }
        }
        .task(id: safeSearch) {
            await vm.load(safeOnly: safeSearch)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var content: some View {
        if #available(iOS 26.0, *) {
            // Scroll-edge blur is separate from the navigation bar background.
            scrollContent
                .scrollEdgeEffectHidden(vm.hero != nil, for: .top)
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing:
                    Theme.Space.xl
            ) {

                // Start the artwork at the top, including during refresh.
                heroSection

                if vm.isRefreshing {
                    ProgressView("Updating anime…")
                        .font(Theme.Text.meta)
                } else if vm.refreshError != nil {
                    Text("Some anime couldn’t update. Pull to refresh.")
                        .font(Theme.Text.meta)
                        .foregroundStyle(Theme.Colors.secondary)
                        .padding(.horizontal, Theme.Space.screen)
                }

                // T6.4
                if !vm.seasonal.isEmpty { seasonalSection }

                // T6.5 / T6.6
                if !vm.top.isEmpty { topSection }
            }
            .padding(
                .bottom,
                Theme.Space.xxl
            )
        }

        .ignoresSafeArea(.container, edges: vm.hero == nil ? [] : .top)

        // Pull to refresh both endpoints.
        .refreshable {

            await vm.refresh(
                safeOnly:
                    safeSearch
            )
        }

        // Must match GeometryReader.
        .coordinateSpace(
            name:
                "discoverScroll"
        )

        // Animate saved-result status changes.
        .animation(
            Motion.gentle,
            value:
                vm.isShowingCached
        )
    }
}

// MARK: - Hero Section

private extension DiscoverView {

    @ViewBuilder
    var heroSection: some View {

        if let hero = vm.hero {

            NavigationLink(
                value: hero
            ) {

                GeometryReader { geo in

                    let minY =
                        geo.frame(
                            in:
                                .named(
                                    "discoverScroll"
                                )
                        )
                        .minY

                    // Positive minY occurs when
                    // pulling down beyond the top.
                    let stretch = reduceMotion ? 0 :
                        max(
                            0,
                            minY
                        )

                    CachedAsyncImage(
                        url:
                            hero.posterURL,
                        cornerRadius: 0
                    )

                    // Resting height = 420.
                    // Increase height when pulling down.
                    .frame(
                        width:
                            geo.size.width,
                        height:
                            420
                            + stretch
                    )

                    .clipped()

                    // Keeps stretched image anchored
                    // to the top.
                    .offset(
                        y:
                            -stretch
                    )

                    // Existing design-system scrim.
                    .posterScrim()

                    .overlay(
                        alignment:
                            .bottomLeading
                    ) {

                        heroCaption(
                            hero
                        )
                        .padding(
                            Theme
                                .Space
                                .screen
                        )

                        // Caption moves more slowly
                        // than the image -> depth.
                        .offset(
                            y:
                                -stretch
                                * 0.35
                        )
                    }
                    .preference(
                        key: DiscoverHeroOffsetKey.self,
                        value: minY
                    )
                }
                .frame(
                    height: 420
                )
            }
            .buttonStyle(
                .plain
            )

            // T5.3
            // Source for hero zoom.
            .matchedTransitionSource(
                id:
                    hero.malId,
                in: zoom
            )
        }
    }

    func heroCaption(
        _ anime: Anime
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing:
                Theme.Space.xs
        ) {

            Text(
                "AIRING NOW"
            )
            .font(
                .caption2
                    .weight(
                        .bold
                    )
            )
            .foregroundStyle(
                .white
                    .opacity(
                        0.85
                    )
            )
            .padding(
                .horizontal,
                8
            )
            .padding(
                .vertical,
                4
            )
            .background(
                Theme
                    .Colors
                    .accent,
                in:
                    Capsule()
            )

            Text(
                anime
                    .displayTitle
            )
            .font(
                .title
                    .weight(
                        .bold
                    )
            )
            .foregroundStyle(
                .white
            )
            .lineLimit(
                2
            )

            if !anime
                .metaLine
                .isEmpty {

                Text(
                    anime
                        .metaLine
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .white
                        .opacity(
                            0.85
                        )
                )
            }
        }
        .shadow(
            radius: 8
        )
    }
}

// MARK: - Seasonal Carousel

private extension DiscoverView {

    var seasonalSection: some View {

        VStack(
            alignment: .leading,
            spacing:
                Theme.Space.md
        ) {

            SectionHeader(
                title:
                    "Airing This Season",
                subtitle:
                    "\(vm.seasonal.count) titles"
            )

            ScrollView(
                .horizontal,
                showsIndicators:
                    false
            ) {

                LazyHStack(
                    spacing:
                        Theme.Space.md
                ) {

                    ForEach(
                        vm.seasonal
                    ) { anime in

                        NavigationLink(
                            value:
                                anime
                        ) {

                            PosterCard(
                                anime:
                                    anime,
                                width:
                                    132
                            )
                        }
                        .buttonStyle(
                            .plain
                        )

                        // T5.3 zoom
                        .matchedTransitionSource(
                            id:
                                anime.malId,
                            in:
                                zoom
                        )
                    }
                }

                // Required for snapping.
                .scrollTargetLayout()

                .padding(
                    .horizontal,
                    Theme.Space.screen
                )
            }

            // T6.4
            // Horizontal card snapping.
            .scrollTargetBehavior(
                .viewAligned
            )
        }
    }
}

// MARK: - Top Rated Grid

private extension DiscoverView {

    var topSection: some View {

        VStack(
            alignment: .leading,
            spacing:
                Theme.Space.md
        ) {

            SectionHeader(
                title:
                    "Top Rated"
            )

            LazyVGrid(
                columns: [

                    GridItem(
                        .flexible(),
                        spacing:
                            Theme.Space.md
                    ),

                    GridItem(
                        .flexible(),
                        spacing:
                            Theme.Space.md
                    )
                ],
                spacing:
                    Theme.Space.lg
            ) {

                // T6.6:
                // Enumerated gives us index for stagger.
                ForEach(
                    Array(
                        vm.top
                            .enumerated()
                    ),
                    id:
                        \.element.malId
                ) { index, anime in

                    NavigationLink(
                        value:
                            anime
                    ) {

                        PosterCard(
                            anime:
                                anime
                        )
                    }
                    .buttonStyle(
                        .plain
                    )

                    // T5.3
                    // Poster-to-detail zoom.
                    .matchedTransitionSource(
                        id:
                            anime.malId,
                        in:
                            zoom
                    )

                    // MARK: T6.6
                    // Initially hidden.

                    .opacity(
                        appeared
                            .contains(
                                anime.malId
                            )
                        ? 1
                        : 0
                    )

                    // Initially 18pt lower.

                    .offset(
                        y:
                            appeared
                                .contains(
                                    anime.malId
                                )
                            ? 0
                            : 18
                    )

                    // Animate when cell first appears.

                    .onAppear {

                        guard
                            !appeared
                                .contains(
                                    anime.malId
                                )
                        else {
                            return
                        }

                        // Accessibility:
                        // show immediately when
                        // Reduce Motion is enabled.

                        guard
                            !reduceMotion
                        else {

                            appeared.insert(
                                anime.malId
                            )

                            return
                        }

                        // Cap delay with index % 6.
                        withAnimation(
                            Motion
                                .gentle
                                .delay(
                                    Double(
                                        index
                                        % 6
                                    )
                                    * 0.05
                                )
                        ) {

                            _ =
                                appeared
                                .insert(
                                    anime
                                        .malId
                                )
                        }
                    }

                    // MARK: T6.5
                    // Infinite scrolling.

                    .task(id: vm.isRefreshing) {

                        await vm
                            .loadMoreIfNeeded(
                                current:
                                    anime,
                                safeOnly:
                                    safeSearch
                            )
                    }
                }
            }
            .padding(
                .horizontal,
                Theme.Space.screen
            )

            // Pagination spinner.

            if vm.isLoadingMore {

                ProgressView()
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        Theme.Space.lg
                    )
            } else if let error = vm.paginationError {
                PaginationRetryRow(error: error, isLoading: vm.isLoadingMore) {
                    await vm.retryLoadMore(safeOnly: safeSearch)
                }
            }
        }
    }
}

// MARK: - Reusable Section Header

struct SectionHeader: View {

    let title: String

    var subtitle: String?

    var body: some View {

        HStack(
            alignment:
                .firstTextBaseline
        ) {

            Text(
                title
            )
            .font(
                Theme
                    .Text
                    .sectionTitle
            )
            .foregroundStyle(
                Theme
                    .Colors
                    .primary
            )

            Spacer()

            if let subtitle {

                Text(
                    subtitle
                )
                .font(
                    Theme
                        .Text
                        .meta
                )
                .foregroundStyle(
                    Theme
                        .Colors
                        .secondary
                )
            }
        }
        .padding(
            .horizontal,
            Theme.Space.screen
        )
    }
}
