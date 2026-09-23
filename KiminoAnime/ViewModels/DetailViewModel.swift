import SwiftUI

@Observable
final class DetailViewModel {
    private(set) var anime: Anime?
    private(set) var characters: [AnimeCharacterEntry] = []
    private(set) var recommendations: [RecommendationEntry] = []
    private(set) var error: APIError?
    private(set) var charactersError: APIError?
    private(set) var recommendationsError: APIError?
    private(set) var isLoading = false
    private(set) var isLoadingCharacters = false
    private(set) var isLoadingRecommendations = false

    private var requestGeneration = UUID()

    func load(seed: Anime?, id: Int) async {
        let generation = UUID()
        requestGeneration = generation
        anime = seed
        isLoading = true
        error = nil
        charactersError = nil
        recommendationsError = nil
        isLoadingCharacters = false
        isLoadingRecommendations = false
        do {
            let full = try await KitsuClient.shared.animeDetail(id: id)
            guard generation == requestGeneration, !Task.isCancelled else { return }
            anime = full.data
            isLoading = false
            error = nil
            await loadSupportingContent(animeId: id, generation: generation)
        } catch let apiError as APIError {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            isLoading = false
            error = apiError
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            isLoading = false
            self.error = .badResponse
        }
    }

    func retryCharacters(animeId: Int) async {
        await loadCharacters(animeId: animeId, generation: requestGeneration)
    }

    func retryRecommendations(animeId: Int) async {
        await loadRecommendations(animeId: animeId, generation: requestGeneration)
    }

    private func loadSupportingContent(animeId: Int, generation: UUID) async {
        async let charactersTask: Void = loadCharacters(
            animeId: animeId,
            generation: generation
        )
        async let recommendationsTask: Void = loadRecommendations(
            animeId: animeId,
            generation: generation
        )
        _ = await (charactersTask, recommendationsTask)
    }

    private func loadCharacters(animeId: Int, generation: UUID) async {
        guard generation == requestGeneration else { return }
        isLoadingCharacters = true
        charactersError = nil
        defer {
            if generation == requestGeneration {
                isLoadingCharacters = false
            }
        }

        do {
            let response = try await KitsuClient.shared.characters(animeId: animeId)
            guard generation == requestGeneration, !Task.isCancelled else { return }
            characters = Array(response.data.prefix(15))
        } catch let apiError as APIError {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            guard apiError != .cancelled else { return }
            charactersError = apiError
        } catch is CancellationError {
            return
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            charactersError = .badResponse
        }
    }

    private func loadRecommendations(animeId: Int, generation: UUID) async {
        guard generation == requestGeneration else { return }
        isLoadingRecommendations = true
        recommendationsError = nil
        defer {
            if generation == requestGeneration {
                isLoadingRecommendations = false
            }
        }

        do {
            let response = try await KitsuClient.shared.recommendations(animeId: animeId)
            guard generation == requestGeneration, !Task.isCancelled else { return }
            recommendations = Array(response.data.prefix(10))
        } catch let apiError as APIError {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            guard apiError != .cancelled else { return }
            recommendationsError = apiError
        } catch is CancellationError {
            return
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            recommendationsError = .badResponse
        }
    }
}
