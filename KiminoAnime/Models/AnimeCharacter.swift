import Foundation
 
/// One entry from GET /anime/{id}/characters
struct AnimeCharacterEntry: Decodable, Identifiable, Hashable {
    let character: CharacterInfo
    let role: String?          // "Main" or "Supporting"
    let favorites: Int?
    let voiceActors: [VoiceActor]?
 
    var id: Int { character.malId }
 
    struct CharacterInfo: Decodable, Hashable {
        let malId: Int
        let name: String
        let images: CharacterImages
 
        var portraitURL: URL? {
            URL(string: images.jpg.imageUrl ?? "")
        }
    }
 
    struct CharacterImages: Decodable, Hashable {
        let jpg: ImageSet
        struct ImageSet: Decodable, Hashable {
            let imageUrl: String?
            let smallImageUrl: String?
        }
    }
 
    struct VoiceActor: Decodable, Hashable {
        let person: Person
        let language: String?
 
        struct Person: Decodable, Hashable {
            let malId: Int
            let name: String
        }
    }
 
    /// The Japanese VA, if listed — nicer than showing whichever came first.
    var japaneseVoiceActor: String? {
        voiceActors?.first { $0.language == "Japanese" }?.person.name
    }
}
