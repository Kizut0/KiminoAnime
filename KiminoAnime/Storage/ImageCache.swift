import UIKit
 
actor ImageCache {
 
    static let shared = ImageCache()
 
    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 250
        c.totalCostLimit = 80 * 1024 * 1024   // ~80 MB
        return c
    }()
 
    private init() {}
 
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
 
    func insert(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
 
    func clear() {
        cache.removeAllObjects()
    }
}
