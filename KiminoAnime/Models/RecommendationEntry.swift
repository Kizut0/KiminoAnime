import Foundation

/// One row in the Detail screen's "Related anime" rail.
struct RecommendationEntry: Codable, Identifiable, Hashable {
    let entry: Anime
    let votes: Int?

    var id: Int { entry.malId }
}
