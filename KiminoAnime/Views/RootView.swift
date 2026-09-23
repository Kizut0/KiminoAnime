import SwiftUI

struct RootView: View {
    @AppStorage(PrefKey.lastTab) private var selection = 0
    @AppStorage(PrefKey.appearance) private var appearance = AppAppearance.system
    @State private var storageErrorMessage: String?

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
        .preferredColorScheme(appearance.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .libraryStoreSaveFailed)) { notification in
            storageErrorMessage = notification.object as? String
                ?? "Your changes could not be saved. Please try again."
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("offlineCacheSaveFailed"))) { notification in
            storageErrorMessage = notification.object as? String
                ?? "Offline browsing data could not be saved."
        }
        .alert(
            "Couldn't save data",
            isPresented: Binding(
                get: { storageErrorMessage != nil },
                set: { if !$0 { storageErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(storageErrorMessage ?? "Your changes could not be saved. Please try again.")
        }
    }
}
