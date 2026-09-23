//
//  SettingsView.swift
//  KiminoAnime
//
//  Placeholder created in T5.1 so the tab bar compiles.
//  Real implementation is Part 10 (Screen 5 — Settings), owned by Hsu.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var saved: [SavedAnime]
    @AppStorage(PrefKey.safeSearch) private var safeSearch = true
    @AppStorage(PrefKey.appearance) private var appearance = AppAppearance.system
    @State private var cacheSize = DiskCache.formattedSize
    @State private var showClearListConfirm = false

    var body: some View {
        NavigationStack {
            Form { contentSection; appearanceSection; storageSection; statisticsSection; aboutSection }
                .navigationTitle("Settings")
        }
    }
}

private extension SettingsView {
    var contentSection: some View {
        Section { Toggle(isOn: $safeSearch) { Label("Safe search", systemImage: "shield.lefthalf.filled") } }
        header: { Text("Content") }
        footer: { Text("Filters adult titles out of Discover and Search. Applied to every API request.") }
    }
    var appearanceSection: some View {
        Section {
            Picker(selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.menu)
        }
        header: { Text("Appearance") }
        footer: { Text("Choose Light or Dark, or use System to match your device.") }
    }
    var storageSection: some View {
        Section("Storage") {
            LabeledContent("Saved titles", value: "\(saved.count)")
            LabeledContent("Cached responses", value: cacheSize)
            Button("Clear cache") { DiskCache.clear(); Task { await ImageCache.shared.clear() }; withAnimation { cacheSize = DiskCache.formattedSize } }
            Button("Clear My List", role: .destructive) { showClearListConfirm = true }.disabled(saved.isEmpty)
        }
        .confirmationDialog("Remove all \(saved.count) saved titles?", isPresented: $showClearListConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { LibraryStore(context: context).removeAll() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This cannot be undone.") }
    }
    var statisticsSection: some View {
        Section("Your stats") {
            LabeledContent("Episodes watched", value: "\(saved.reduce(0) { $0 + $1.episodesWatched })")
            LabeledContent("Completed", value: "\(saved.filter { $0.status == .completed }.count)")
            LabeledContent("Currently watching", value: "\(saved.filter { $0.status == .watching }.count)")
            if let top = saved.compactMap({ $0.score }).max() { LabeledContent("Highest rated saved", value: String(format: "%.2f", top)) }
        }
    }
    var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
            Link(destination: URL(string: "https://kitsu.app")!) { LabeledContent("Data by", value: "Kitsu API") }
            Link(destination: URL(string: "https://kitsu.app")!) { LabeledContent("Source", value: "Kitsu") }
        } header: { Text("About") }
        footer: { Text("KIMINO Anime uses the Kitsu API. Not affiliated with Kitsu. Built as a student project.") }
    }
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
