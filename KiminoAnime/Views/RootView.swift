//
//  RootView.swift
//  KiminoAnime
//
//  T5.1 — the tab bar shell. Binding `selection` to @AppStorage means
//  the app reopens on whichever tab you left — a persistence detail
//  worth mentioning in the demo for one line of code.
//
//  NOTE: PrefKey.lastTab (and PrefKey.safeSearch / .reduceMotion used
//  elsewhere) live in Storage/Preferences.swift, which is Part 3
//  (persistence layer) and is not implemented yet. This file will not
//  compile until that lands — that's a teammate's task, not a bug here.
//

import SwiftUI

struct RootView: View {
    @AppStorage(PrefKey.lastTab) private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles") }
                .tag(0)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)
            MyListView()
                .tabItem { Label("My List", systemImage: "bookmark.fill") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(Theme.Colors.accent)
    }
}
