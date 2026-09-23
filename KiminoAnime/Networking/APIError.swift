import Foundation
 
enum APIError: LocalizedError, Equatable {
    case badURL
    case badResponse
    case notFound
    case rateLimited
    case server(Int)
    case decoding(String)
    case offline
    case cancelled
 
    /// Shown to the user. Plain language, no jargon, no error codes
    /// except where a code genuinely helps.
    var errorDescription: String? {
        switch self {
        case .badURL:
            "We couldn't build that request. Please try again."
        case .badResponse:
            "We got an unexpected response from the server."
        case .notFound:
            "We couldn't find that title on Kitsu."
        case .rateLimited:
            "You're going a bit fast — give it a second and try again."
        case .server(403):
            "Kitsu is currently refusing requests. Please try again later."
        case .server(408), .server(504):
            "The anime service took too long to respond. Please try again."
        case .server(let code):
            "The anime service is temporarily unavailable (error \(code))."
        case .decoding:
            "We couldn't read the data we got back."
        case .offline:
            "You're offline. Connect to the internet to load this content."
        case .cancelled:
            "Request cancelled."
        }
    }
 
    /// Should the UI offer a Retry button?
    var isRetryable: Bool {
        switch self {
        case .notFound, .decoding, .cancelled: false
        default: true
        }
    }
 
    /// SF Symbol for the error state view.
    var symbol: String {
        switch self {
        case .offline:      "wifi.slash"
        case .notFound:     "questionmark.circle"
        case .rateLimited:  "hourglass"
        default:            "exclamationmark.triangle"
        }
    }
}
