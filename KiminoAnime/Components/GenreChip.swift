//
//  GenreChip.swift
//  KiminoAnime
//
//  T4.8 — filter/display chip for genre names. Selectable variant
//  is used on Search; plain (non-interactive) variant on Detail.
//

import SwiftUI

struct GenreChip: View {
    let title: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Text(title)
            .font(Theme.Text.chip)
            .foregroundStyle(isSelected ? .white : Theme.Colors.primary)
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(isSelected ? Theme.Colors.accent : Theme.Colors.card)
            }
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : Theme.Colors.divider, lineWidth: 1)
            }
            .contentShape(Capsule())
            .onTapGesture { action?() }
            .animation(Motion.snappy, value: isSelected)
    }
}
