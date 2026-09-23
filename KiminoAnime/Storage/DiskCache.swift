import Foundation
import CryptoKit


nonisolated enum DiskCache {
 
    private static var directory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appending(path: "KiminoAnimeCache")
        if !FileManager.default.fileExists(atPath: dir.path()) {
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static var legacyDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "KiminoAnimeCache")
    }

    static func key(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
 
    static func save<T: Encodable>(_ value: T, as name: String) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: directory.appending(path: name + ".json"),
                           options: .atomic)
        } catch {
            NotificationCenter.default.post(
                name: Notification.Name("offlineCacheSaveFailed"),
                object: "Offline browsing data couldn't be saved. Check available device storage."
            )
        }
    }
 
    static func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        let url = directory.appending(path: name + ".json")
        if let data = try? Data(contentsOf: url),
           let value = try? JSONDecoder().decode(T.self, from: data) {
            return value
        }
        // Preserve Discover/genre data written by earlier app versions.
        let oldURL = legacyDirectory.appending(path: name + ".json")
        guard let data = try? Data(contentsOf: oldURL),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else { return nil }
        try? data.write(to: url, options: .atomic)
        return value
    }
 
    static func age(of name: String) -> TimeInterval? {
        let current = directory.appending(path: name + ".json")
        let url = FileManager.default.fileExists(atPath: current.path())
            ? current : legacyDirectory.appending(path: name + ".json")
        guard let attrs = try? FileManager.default
                .attributesOfItem(atPath: url.path()),
              let modified = attrs[.modificationDate] as? Date
        else { return nil }
        return Date().timeIntervalSince(modified)
    }
 
    static func sizeInBytes() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?
                .fileSize ?? 0
            return total + size
        }
    }
 
    static var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes()),
                                  countStyle: .file)
    }
 
    static func clear() {
        for folder in [directory, legacyDirectory] {
            guard let files = try? FileManager.default
                    .contentsOfDirectory(at: folder,
                                         includingPropertiesForKeys: nil)
            else { continue }
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }
}

struct CachedAnimePage: Codable {
    let items: [Anime]
    let page: Int
    let hasNextPage: Bool
}

nonisolated enum OfflineCacheKey {
    static func search(_ query: String, genres: [Int], safeOnly: Bool) -> String {
        let identity = "search|\(safeOnly)|\(query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(genres.sorted())"
        return "search-v1-" + DiskCache.key(for: identity)
    }

    static func genre(_ id: Int, safeOnly: Bool) -> String {
        "genre-v1-\(id)-\(safeOnly)"
    }

    static func detail(_ id: Int) -> String { "detail-v1-\(id)" }
    static func characters(_ id: Int) -> String { "characters-v1-\(id)" }
    static func recommendations(_ id: Int) -> String { "recommendations-v1-\(id)" }
}
