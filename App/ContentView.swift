import AppKit
import SwiftUI
import WidgetKit

struct ContentView: View {
    @EnvironmentObject private var model: UsageModel
    @State private var showingLogin = false
    @State private var pastedToken = ""

    var body: some View {
        Group {
            if model.snapshot.isSignedIn {
                signedIn
            } else {
                signedOut
            }
        }
        .frame(minWidth: 400, minHeight: 520)
        .padding(20)
        .sheet(isPresented: $showingLogin) {
            LoginView { session in
                showingLogin = false
                model.signIn(session: session)
            }
        }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Text("Sign in once. The desktop widget and this window then show the same allowance bars and token totals as the Cursor dashboard, and refresh every 5 minutes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Button("Use the account signed in to Cursor") {
                    model.useLocalCursorAccount()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Sign in with email or SSO") {
                    showingLogin = true
                }
                .controlSize(.large)
            }

            DisclosureGroup("Paste a session token") {
                Text("If browser sign-in is blocked, copy the WorkosCursorSessionToken cookie from cursor.com and paste it here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                SecureField("Session token", text: $pastedToken)
                Button("Save token") {
                    model.signIn(session: pastedToken)
                    pastedToken = ""
                }
                .disabled(pastedToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let error = model.snapshot.error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            widgetHelp
        }
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            allowanceCard
            tokenCard
            if let error = model.snapshot.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text(updatedLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Sign Out", role: .destructive) {
                    model.signOut()
                }
            }
            widgetHelp
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cursor Tokens")
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var subtitle: String {
        let snapshot = model.snapshot
        guard snapshot.isSignedIn else { return "Not signed in" }
        var parts: [String] = []
        if let email = snapshot.email, !email.isEmpty {
            parts.append(email)
        }
        if let membership = snapshot.membershipLabel {
            parts.append(membership)
        }
        return parts.isEmpty ? "Signed in" : parts.joined(separator: " · ")
    }

    private var allowanceCard: some View {
        GroupBox("Included") {
            VStack(alignment: .leading, spacing: 16) {
                AllowanceMeter(
                    title: "Cursor Models",
                    detail: "Includes Cursor Grok and Composer",
                    percent: model.snapshot.cursorModelsPercent,
                    tint: .blue
                )
                AllowanceMeter(
                    title: "Other Models",
                    detail: "Models outside the Cursor pool",
                    percent: model.snapshot.otherModelsPercent,
                    tint: .primary.opacity(0.55)
                )
            }
            .padding(.top, 6)
        }
    }

    private var tokenCard: some View {
        GroupBox("Tokens") {
            HStack(spacing: 0) {
                TokenColumn(label: "Today", tokens: model.snapshot.todayTokens)
                Divider().padding(.vertical, 4)
                TokenColumn(label: "7 days", tokens: model.snapshot.weekTokens)
                Divider().padding(.vertical, 4)
                TokenColumn(label: "30 days", tokens: model.snapshot.monthTokens)
            }
            .padding(.top, 4)
        }
    }

    private var updatedLine: String {
        let formatted = model.snapshot.updatedAt.formatted(date: .omitted, time: .shortened)
        return "Updated \(formatted) · refreshes every 5 minutes"
    }

    private var widgetHelp: some View {
        DisclosureGroup("Add the desktop widget") {
            Text("Control-click the desktop, choose Edit Widgets, search for Cursor Usage, and drag the small widget onto the desktop. It is the same size as the small Weather widget.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }
}

private struct AllowanceMeter: View {
    var title: String
    var detail: String
    var percent: Double?
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(UsageFormatting.formatPercent(percent))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            UsageBar(percent: percent, tint: tint, height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(UsageFormatting.formatPercent(percent))")
    }
}

private struct TokenColumn: View {
    var label: String
    var tokens: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(UsageFormatting.formatTokenCount(tokens))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(UsageFormatting.formatTokenCount(tokens)) tokens")
    }
}

struct UsageBar: View {
    var percent: Double?
    var tint: Color
    var height: CGFloat = 6
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(renderingMode == .accented ? AnyShapeStyle(.primary) : AnyShapeStyle(tint))
                    .frame(width: max(0, geo.size.width * UsageFormatting.barFraction(percent)))
            }
        }
        .frame(height: height)
    }
}

struct MenuBarMenu: View {
    @ObservedObject var model: UsageModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Cursor Tokens") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Refresh") {
            Task { await model.refresh() }
        }
        .disabled(model.isRefreshing)
        Divider()
        if model.snapshot.isSignedIn {
            Button("Sign Out") { model.signOut() }
        }
        Button("Quit") { NSApp.terminate(nil) }
    }
}
