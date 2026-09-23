import UIKit
import CryptoKit
 
actor ImageCache {
 
    static let shared = ImageCache()
 
    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 250
        c.totalCostLimit = 80 * 1024 * 1024   // ~80 MB
        return c
    }()

    private var writesSincePrune = 0
    private var reportedSaveFailure = false

    private var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appending(path: "KiminoAnimeImages")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func fileURL(for url: URL) -> URL {
        let name = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directory.appending(path: name + ".img")
    }
 
    private init() {}
 
    func image(for url: URL) -> UIImage? {
        if let image = cache.object(forKey: url as NSURL) { return image }
        let file = fileURL(for: url)
        guard let data = try? Data(contentsOf: file),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL,
                        cost: Int(image.size.width * image.size.height * 4))
        return image
    }
 
    func insert(_ image: UIImage, for url: URL, data: Data? = nil) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
        let file = fileURL(for: url)
        guard !FileManager.default.fileExists(atPath: file.path()) else { return }
        let stored = (data?.count ?? .max) <= 2_000_000
            ? data : image.jpegData(compressionQuality: 0.7)
        guard let stored, stored.count <= 2_000_000 else { return }
        do {
            try stored.write(to: file, options: .atomic)
            reportedSaveFailure = false
        } catch {
            if !reportedSaveFailure {
                reportedSaveFailure = true
                NotificationCenter.default.post(
                    name: Notification.Name("offlineCacheSaveFailed"),
                    object: "Offline artwork couldn't be saved. Check available device storage."
                )
            }
            return
        }
        writesSincePrune += 1
        if writesSincePrune >= 20 {
            writesSincePrune = 0
            pruneIfNeeded()
        }
    }

    private func pruneIfNeeded() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys)
        ) else { return }
        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.1 }
        guard total > 120_000_000 else { return }
        for entry in entries.sorted(by: { $0.2 < $1.2 }) {
            try? FileManager.default.removeItem(at: entry.0)
            total -= entry.1
            if total <= 80_000_000 { break }
        }
    }
 
    func clear() {
        cache.removeAllObjects()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        files.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
