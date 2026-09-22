//
//  StateViews.swift
//  KiminoAnime
//
//  T4.9 — shared loading / error / empty state views so every screen
//  fails and recovers the same way instead of inventing its own.
//

import SwiftUI

struct LoadingStateView: View {
    var message: String = "Loading…"
    var body: some View {
        VStack(spacing: Theme.Space.md) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(Theme.Text.meta)
                .foregroundStyle(Theme.Colors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let error: APIError
    var retry: (() async -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: error.symbol)
        } description: {
            Text(error.errorDescription ?? "Please try again.")
        } actions: {
            if error.isRetryable, let retry {
                Button("Try again") {
                    Task { await retry() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var symbol: String = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Small banner for "offline, showing cached data".
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "wifi.slash")
            Text("Offline — showing saved results")
                .font(Theme.Text.meta)
            Spacer()
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, Theme.Space.screen)
        .padding(.vertical, Theme.Space.sm)
        .background(.orange.opacity(0.12))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
