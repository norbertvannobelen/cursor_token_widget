import AppIntents
import os
import SwiftUI
import WidgetKit

private let widgetLogger = Logger(subsystem: "org.tx.cursortokenwidget", category: "widget")

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
        let cached = SnapshotStore.load()
        let sessionPresent = SessionStore.load() != nil
        let snapshot: UsageSnapshot
        if let cached, cached.isSignedIn, !sessionPresent {
            snapshot = cached
        } else if !sessionPresent {
            snapshot = .signedOut()
        } else if let cached,
                  cached.isSignedIn,
                  cached.error == nil,
                  Date().timeIntervalSince(cached.updatedAt) < UsageTiming.cacheFreshness {
            snapshot = cached
        } else {
            snapshot = await UsageRefresh.refresh()
        }
        publishStatus(snapshot, sessionPresent: sessionPresent)
        return snapshot
    }

    private static func publishStatus(_ snapshot: UsageSnapshot, sessionPresent: Bool) {
        let cursor = snapshot.cursorModelsPercent.map { String(Int($0.rounded())) } ?? "nil"
        let other = snapshot.otherModelsPercent.map { String(Int($0.rounded())) } ?? "nil"
        let line = "signedIn=\(snapshot.isSignedIn) session=\(sessionPresent) cursor=\(cursor) other=\(other) today=\(snapshot.todayTokens.map(String.init) ?? "nil") week=\(snapshot.weekTokens.map(String.init) ?? "nil") month=\(snapshot.monthTokens.map(String.init) ?? "nil")"
        if let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? Data(line.utf8).write(to: directory.appendingPathComponent("widget-status.txt"), options: .atomic)
        }
        widgetLogger.info("\(line, privacy: .public)")
    }
}

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CursorUsageWidget", provider: UsageProvider()) { entry in
            Button(intent: StayOnWidgetIntent()) {
                UsageWidgetView(snapshot: entry.snapshot)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        .padding(10)
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 5) {
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
            CompactMeter(
                title: "Cursor",
                value: UsageFormatting.formatPercent(snapshot.cursorModelsPercent),
                percent: snapshot.cursorModelsPercent,
                tint: .blue
            )
            CompactMeter(
                title: "Other",
                value: UsageFormatting.formatPercent(snapshot.otherModelsPercent),
                percent: snapshot.otherModelsPercent,
                tint: .primary.opacity(0.55)
            )
            if let demand = snapshot.onDemand {
                CompactMeter(title: "On-demand", value: demand.pairText, percent: demand.percent, tint: .orange)
            }
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
            Text("Sign in to load model allowance and token use.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct CompactMeter: View {
    var title: String
    var value: String
    var percent: Double?
    var tint: Color
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(barFill)
                        .frame(width: max(0, geo.size.width * UsageFormatting.barFraction(percent)))
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value)")
    }

    private var barFill: AnyShapeStyle {
        if UsageFormatting.exceedsWarning(percent) {
            return AnyShapeStyle(.red)
        }
        if renderingMode == .accented {
            return AnyShapeStyle(.primary)
        }
        return AnyShapeStyle(tint)
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
