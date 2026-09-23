import SwiftUI

struct ShimmerView: View {
    var cornerRadius: CGFloat = Theme.Radius.poster

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.Colors.divider.opacity(0.6))
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.28), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.55)
                    .phaseAnimator([-0.7, 1.7]) { view, phase in
                        view.offset(x: geo.size.width * phase)
                    } animation: { _ in
                        .linear(duration: 1.1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }
}

#Preview {
    ShimmerView()
        .frame(width: 140, height: 210)
        .padding()
}
