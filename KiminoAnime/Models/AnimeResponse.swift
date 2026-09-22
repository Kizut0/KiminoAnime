//
//  AnimeResponse.swift
//  KiminoAnime
//
//  Created by Aung Myat Oo Gyaw on 9/9/26.
//
//  NOTE (Anuson, 9/22): this file was empty and was blocking the whole
//  build — KitsuClient.swift and DiscoverViewModel/SearchViewModel all
//  reference AnimeResponse<T> and Pagination, which lived nowhere.
//  Drafted from how those files actually call it (see the six
//  `AnimeResponse(data:pagination:)` call sites in KitsuClient.swift and
//  `Pagination(lastVisiblePage:hasNextPage:items:)` in
//  KitsuResource.swift's `pagination(page:)`), not just copied from the
//  manual. Aung — please review and adjust if this doesn't match what
//  you intended.
//

import Foundation

/// Every KitsuClient method returns its result wrapped in this envelope —
/// mirrors the original Jikan-based JikanResponse<T> design, renamed for
/// the move to the Kitsu API. Unlike the old version, this isn't decoded
/// directly from JSON: KitsuClient builds it by hand from a
/// KitsuDocument<T>, so no Decodable conformance is needed here.
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
