//
//  ScoreRing.swift
//  KiminoAnime
//
//  T4.7 — animated score ring for the Detail screen header.
//

import SwiftUI

struct ScoreRing: View {
    let score: Double            // 0...10
    var size: CGFloat = 78
    var reduceMotion: Bool = false

    @State private var shown: Double = 0

    private var fraction: Double { min(max(score / 10, 0), 1) }

    private var tint: Color {
        switch score {
        case 8...:    .green
        case 6..<8:   Theme.Colors.accent
        case 0.1..<6: .orange
        default:      Theme.Colors.secondary
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.divider, lineWidth: size * 0.09)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(tint, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(score, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("SCORE")
                    .font(.system(size: size * 0.11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.secondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion {
                shown = fraction
            } else {
                withAnimation(Motion.reveal) { shown = fraction }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Score \(String(format: "%.2f", score)) out of 10")
    }
}

#Preview {
    HStack(spacing: 20) {
        ScoreRing(score: 9.09)
        ScoreRing(score: 7.2)
        ScoreRing(score: 4.8)
    }
    .padding()
}
