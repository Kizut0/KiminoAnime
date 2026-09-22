//
//  Theme.swift
//  KiminoAnime
//
//  T4.2 — spacing, radius, typography, colour tokens.
//  After this file, no view hard-codes a number.
//

import SwiftUI

enum Theme {

    // MARK: Spacing — a 4pt scale, nothing between the steps
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let screen: CGFloat = 16   // standard horizontal inset
    }

    enum Radius {
        static let chip: CGFloat = 8
        static let card: CGFloat = 14
        static let poster: CGFloat = 12
        static let sheet: CGFloat = 24
    }

    enum Colors {
        static let background = Color("AppBackground")
        static let card       = Color("CardBackground")
        static let accent     = Color("AccentPrimary")
        static let primary    = Color("TextPrimary")
        static let secondary  = Color("TextSecondary")
        static let divider    = Color("Divider")
    }

    /// Every size below is a Dynamic Type text style, never a fixed
    /// point size — the app must survive the accessibility text sizes.
    enum Text {
        static let screenTitle  = Font.largeTitle.weight(.bold)
        static let sectionTitle = Font.title3.weight(.semibold)
        static let cardTitle    = Font.subheadline.weight(.semibold)
        static let body         = Font.body
        static let meta         = Font.caption
        static let chip         = Font.caption.weight(.medium)
    }

    /// The poster aspect ratio MyAnimeList/Kitsu covers use. Hard-coding
    /// it once keeps every grid cell, row and header consistent.
    static let posterAspect: CGFloat = 2.0 / 3.0
}

// Convenience: a scrim so white text is legible over any poster.
extension View {
    func posterScrim() -> some View {
        overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }
}
