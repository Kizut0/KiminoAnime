import SwiftUI

enum Motion {
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.85)
    static let quick  = Animation.easeOut(duration: 0.2)
    static let reveal = Animation.easeOut(duration: 0.9)

    /// Honours the user's system Reduce Motion setting.
    static func respectful(_ animation: Animation, reduced: Bool) -> Animation? {
        reduced ? nil : animation
    }
}
