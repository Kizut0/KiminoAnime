import SwiftUI

@Observable
final class DetailViewModel {
    private(set) var anime: Anime?
    private(set) var characters: [AnimeCharacterEntry] = []
    private(set) var recommendations: [RecommendationEntry] = []
    private(set) var error: APIError?
    private(set) var isLoading = false

    func load(seed: Anime?, id: Int) async {
        anime = seed
        isLoading = seed == nil
        error = nil
        do {
            let full = try await KitsuClient.shared.animeDetail(id: id)
            anime = full.data
            isLoading = false
            async let charactersCall = KitsuClient.shared.characters(animeId: id)
            async let recommendationsCall = KitsuClient.shared.recommendations(animeId: id)
            characters = (try? await charactersCall)?.data.prefix(15).map { $0 } ?? []
            recommendations = (try? await recommendationsCall)?.data.prefix(10).map { $0 } ?? []
        } catch let apiError as APIError {
            isLoading = false
            if anime == nil { error = apiError }
        } catch {
            isLoading = false
            if anime == nil { self.error = .badResponse }
        }
    }
}
