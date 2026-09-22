import Foundation
 
/// JSON snapshots of API responses, so Discover renders offline.
/// Lives in Caches/ — iOS may reclaim it under storage pressure,
/// which is correct for data we can always refetch.
enum DiskCache {
 
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
