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
            Label(error == .offline ? "You're offline" : "Something went wrong", systemImage: error.symbol)
        } description: {
            Text(error == .offline
                 ? "Connect to the internet to load this content."
                 : (error.errorDescription ?? "Please try again."))
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

struct PaginationRetryRow: View {
    let error: APIError
    let isLoading: Bool
    let retry: () async -> Void

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Couldn't load more")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
                Text(error.errorDescription ?? "Please try again.")
                    .font(Theme.Text.meta)
                    .foregroundStyle(Theme.Colors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Space.sm)

            if !isLoading {
                Button("Try again") {
                    Task { await retry() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, Theme.Space.screen)
        .padding(.vertical, Theme.Space.md)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .padding(.horizontal, Theme.Space.screen)
        .accessibilityElement(children: .combine)
    }
}

struct InlineRetryRow: View {
    let title: String
    let error: APIError
    let isLoading: Bool
    let retry: () async -> Void

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
                Text(error.errorDescription ?? "Please try again.")
                    .font(Theme.Text.meta)
                    .foregroundStyle(Theme.Colors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Space.sm)

            if !isLoading {
                Button("Try again") {
                    Task { await retry() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, Theme.Space.screen)
        .padding(.vertical, Theme.Space.md)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .padding(.horizontal, Theme.Space.screen)
        .accessibilityElement(children: .combine)
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
