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
    private(set) var hasFreshDetail = false

    private var requestGeneration = UUID()

    func load(
        seed: Anime?,
        id: Int,
        cachedCharacters: [AnimeCharacterEntry] = [],
        cachedRecommendations: [RecommendationEntry] = [],
        onDetailLoaded: ((Anime) -> Void)? = nil,
        onCharactersLoaded: (([AnimeCharacterEntry]) -> Void)? = nil,
        onRecommendationsLoaded: (([RecommendationEntry]) -> Void)? = nil
    ) async {
        let generation = UUID()
        requestGeneration = generation
        anime = seed
        characters = cachedCharacters
        recommendations = cachedRecommendations
        hasFreshDetail = false
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
            hasFreshDetail = true
            isLoading = false
            error = nil
            onDetailLoaded?(full.data)
            await loadSupportingContent(
                animeId: id,
                generation: generation,
                onCharactersLoaded: onCharactersLoaded,
                onRecommendationsLoaded: onRecommendationsLoaded
            )
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

    func retryCharacters(
        animeId: Int,
        onLoaded: (([AnimeCharacterEntry]) -> Void)? = nil
    ) async {
        await loadCharacters(
            animeId: animeId,
            generation: requestGeneration,
            onLoaded: onLoaded
        )
    }

    func retryRecommendations(
        animeId: Int,
        onLoaded: (([RecommendationEntry]) -> Void)? = nil
    ) async {
        await loadRecommendations(
            animeId: animeId,
            generation: requestGeneration,
            onLoaded: onLoaded
        )
    }

    private func loadSupportingContent(
        animeId: Int,
        generation: UUID,
        onCharactersLoaded: (([AnimeCharacterEntry]) -> Void)?,
        onRecommendationsLoaded: (([RecommendationEntry]) -> Void)?
    ) async {
        async let charactersTask: Void = loadCharacters(
            animeId: animeId,
            generation: generation,
            onLoaded: onCharactersLoaded
        )
        async let recommendationsTask: Void = loadRecommendations(
            animeId: animeId,
            generation: generation,
            onLoaded: onRecommendationsLoaded
        )
        _ = await (charactersTask, recommendationsTask)
    }

    private func loadCharacters(
        animeId: Int,
        generation: UUID,
        onLoaded: (([AnimeCharacterEntry]) -> Void)? = nil
    ) async {
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
            onLoaded?(characters)
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

    private func loadRecommendations(
        animeId: Int,
        generation: UUID,
        onLoaded: (([RecommendationEntry]) -> Void)? = nil
    ) async {
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
            onLoaded?(recommendations)
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
