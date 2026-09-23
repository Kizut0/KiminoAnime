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
