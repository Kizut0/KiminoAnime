import Foundation
 
/// One entry from GET /anime/{id}/characters
struct AnimeCharacterEntry: Codable, Identifiable, Hashable {
    let character: CharacterInfo
    let role: String?          // "Main" or "Supporting"
    let favorites: Int?
    let voiceActors: [VoiceActor]?
 
    var id: Int { character.malId }
 
    struct CharacterInfo: Codable, Hashable {
        let malId: Int
        let name: String
        let images: CharacterImages
 
        var portraitURL: URL? {
            URL(string: images.jpg.imageUrl ?? "")
        }
    }
 
    struct CharacterImages: Codable, Hashable {
        let jpg: ImageSet
        struct ImageSet: Codable, Hashable {
            let imageUrl: String?
            let smallImageUrl: String?
        }
    }
 
    struct VoiceActor: Codable, Hashable {
        let person: Person
        let language: String?
 
        struct Person: Codable, Hashable {
            let malId: Int
            let name: String
        }
    }
 
    /// The Japanese VA, if listed — nicer than showing whichever came first.
    var japaneseVoiceActor: String? {
        voiceActors?.first { $0.language == "Japanese" }?.person.name
    }
}
