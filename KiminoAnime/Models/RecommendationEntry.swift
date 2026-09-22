//
//  RecommendationEntry.swift
//  KiminoAnime
//
//  Created by Aung Myat Oo Gyaw on 9/9/26.
//
//  NOTE (Anuson, 9/22): this file was empty; DetailViewModel.swift and
//  DetailView.swift's "Related anime" rail both depend on it. Shape
//  drawn from KitsuClient.swift's `recommendations(animeId:)`, which
//  constructs `RecommendationEntry(entry: .init(malId:title:images:),
//  votes: nil)`, and DetailView.swift's `ForEach(vm.recommendations)`
//  (no `id:` argument, so Identifiable is required). Aung — please
//  review and adjust if this doesn't match what you intended.
//

import Foundation

/// One row in the Detail screen's "Related anime" rail.
struct RecommendationEntry: Identifiable, Hashable {
    let entry: Anime
    let votes: Int?

    var id: Int { entry.malId }
}
