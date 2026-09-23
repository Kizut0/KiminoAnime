import Foundation

struct AnimeResponse<T> {
    let data: T
    let pagination: Pagination?
}

struct Pagination {
    let lastVisiblePage: Int
    let hasNextPage: Bool

    /// Present on search endpoints only — not populated yet.
    let items: Items?

    struct Items {
        let count: Int
        let total: Int
        let perPage: Int
    }
}
