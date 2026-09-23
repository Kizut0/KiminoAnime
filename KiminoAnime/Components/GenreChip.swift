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
