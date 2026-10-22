import SwiftUI
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        if context.isPreview {
            completion(UsageEntry(date: Date(), snapshot: .placeholder))
            return
        }
        completion(UsageEntry(date: Date(), snapshot: SnapshotStore.load() ?? .signedOut()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        Task {
            let snapshot = await Self.loadSnapshot()
            let next = Date().addingTimeInterval(UsageTiming.refreshInterval)
            completion(Timeline(entries: [UsageEntry(date: Date(), snapshot: snapshot)], policy: .after(next)))
        }
    }

    private static func loadSnapshot() async -> UsageSnapshot {
        if SessionStore.load() == nil {
            return .signedOut()
        }
        if let existing = SnapshotStore.load(),
           existing.isSignedIn,
           existing.error == nil,
           Date().timeIntervalSince(existing.updatedAt) < UsageTiming.cacheFreshness {
            return existing
        }
        return await UsageRefresh.refresh()
    }
}

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CursorUsageWidget", provider: UsageProvider()) { entry in
            UsageWidgetView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Cursor Usage")
        .description("Cursor model allowance and recent token use.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct UsageWidgetView: View {
    var snapshot: UsageSnapshot

    var body: some View {
        Group {
            if snapshot.isSignedIn {
                signedIn
            } else {
                signedOut
            }
        }
        .padding(12)
        .widgetURL(URL(string: "cursortokenwidget://open"))
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("Usage")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 4)
                if let membership = snapshot.membershipLabel {
                    Text(membership)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            CompactMeter(title: "Cursor", percent: snapshot.cursorModelsPercent, tint: .blue)
            CompactMeter(title: "Other", percent: snapshot.otherModelsPercent, tint: .primary.opacity(0.55))
            Spacer(minLength: 2)
            VStack(spacing: 2) {
                CompactStat(label: "Today", tokens: snapshot.todayTokens)
                CompactStat(label: "7 days", tokens: snapshot.weekTokens)
                CompactStat(label: "30 days", tokens: snapshot.monthTokens)
            }
        }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cursor")
                .font(.system(size: 13, weight: .semibold))
            Text("Sign in to see model allowance and token use.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("Open the app")
                .font(.system(size: 12, weight: .semibold))
        }
    }
}

private struct CompactMeter: View {
    var title: String
    var percent: Double?
    var tint: Color
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 4)
                Text(UsageFormatting.formatPercent(percent))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(renderingMode == .accented ? AnyShapeStyle(.primary) : AnyShapeStyle(tint))
                        .frame(width: max(0, geo.size.width * UsageFormatting.barFraction(percent)))
                }
            }
            .frame(height: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) models \(UsageFormatting.formatPercent(percent))")
    }
}

private struct CompactStat: View {
    var label: String
    var tokens: Int?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(UsageFormatting.formatTokenCount(tokens))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.system(size: 11, design: .rounded))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(UsageFormatting.formatTokenCount(tokens)) tokens")
    }
}
