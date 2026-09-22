//
//  KiminoAnimeApp.swift
//  KiminoAnime
//
//  Created by Aung Myat Oo Gyaw on 9/9/26.
//  Updated in T5.1: launches RootView (tab shell) instead of the
//  template's ContentView, which has been removed.
//

import SwiftUI
import SwiftData

@main
struct KiminoAnimeApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: SavedAnime.self)
    }
}
