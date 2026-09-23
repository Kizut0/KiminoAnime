import SwiftUI
 
/// Keys in one place so a typo can't silently create a second setting.
enum PrefKey {
    static let safeSearch   = "pref.safeSearch"
    static let appearance   = "pref.appearance"
    static let gridColumns  = "pref.gridColumns"
    static let listSort     = "pref.listSort"
    static let lastTab      = "pref.lastTab"
    static let recentSearches = "pref.recentSearches"
}
 
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum ListSort: String, CaseIterable, Identifiable {
    case dateAdded = "Date added"
    case title     = "Title"
    case score     = "Score"
    case progress  = "Progress"
 
    var id: String { rawValue }
}
 
/// Recent searches are a small array, so JSON in UserDefaults is
/// the right amount of machinery — not a database table.
enum RecentSearches {
    private static let limit = 8
 
    static func load() -> [String] {
        guard let data = UserDefaults.standard
                .data(forKey: PrefKey.recentSearches),
              let list = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return list
    }
 
    static func add(_ term: String) {
        let clean = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }
        var list = load().filter { $0.lowercased() != clean.lowercased() }
        list.insert(clean, at: 0)
        list = Array(list.prefix(limit))
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: PrefKey.recentSearches)
        }
    }
 
    static func clear() {
        UserDefaults.standard.removeObject(forKey: PrefKey.recentSearches)
    }
}
