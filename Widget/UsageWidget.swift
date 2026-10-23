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
            WidgetFace(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Cursor Usage")
        .description("Cursor model allowance and recent token use.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

private struct WidgetFace: View {
    var snapshot: UsageSnapshot
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Button(intent: StayOnWidgetIntent()) {
            UsageWidgetView(snapshot: snapshot, accented: renderingMode == .accented)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}
