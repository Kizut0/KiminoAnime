import Foundation

//  NOTE (Anuson, 9/22): marked DiskCache `nonisolated`. Root cause: the
//  project turns on Swift 6's "approachable concurrency" default isolation
//  (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor in project.pbxproj), which
//  made DiskCache's un-annotated static save/load implicitly
//  @MainActor-isolated. DiscoverViewModel.swift's init uses them as
//  *default parameter values* (readCache/saveCache), and Swift evaluates a
//  function's default-argument expressions in a nonisolated context even
//  when the function itself is @MainActor -- so that was a cross-actor
//  synchronous call and a hard Swift 6 error (DiscoverViewModel.swift:38-39).
//  This didn't need any change to the actual caching logic, just the
//  isolation annotation. I checked Preferences.swift's RecentSearches too --
//  its call sites are all through @MainActor-isolated stored-property
//  defaults (fine as-is), not function-parameter defaults, so it isn't
//  hitting this bug right now and I left it alone.
//  Hsu -- please review; flagging since your commit said "debugging
//  required" and I don't want to step on whatever else you're still
//  checking here.
//
/// JSON snapshots of API responses, so Discover renders offline.
/// Lives in Caches/ — iOS may reclaim it under storage pressure,
/// which is correct for data we can always refetch.
nonisolated enum DiskCache {
 
    private static var directory: URL {
        let base = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appending(path: "KiminoAnimeCache")
        if !FileManager.default.fileExists(atPath: dir.path()) {
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
 
    static func save<T: Encodable>(_ value: T, as name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: directory.appending(path: name + ".json"),
                        options: .atomic)
    }
 
    static func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        let url = directory.appending(path: name + ".json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
 
    static func age(of name: String) -> TimeInterval? {
        let url = directory.appending(path: name + ".json")
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
        guard let files = try? FileManager.default
                .contentsOfDirectory(at: directory,
                                     includingPropertiesForKeys: nil)
        else { return }
        files.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
