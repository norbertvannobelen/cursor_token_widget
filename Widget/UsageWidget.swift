import AppIntents
import AppKit
import os
import SwiftUI
import WidgetKit

private let widgetLogger = Logger(subsystem: "org.tx.cursortokenwidget", category: "widget")

struct UsageWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Cursor Usage"
    static var description = IntentDescription("Allowance, on-demand spend, and recent token use.")

    @Parameter(title: "Menu bar icon", default: false)
    var showsMenuBarIcon: Bool

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct UsageProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .placeholder)
    }

    func snapshot(for configuration: UsageWidgetConfiguration, in context: Context) async -> UsageEntry {
        if context.isPreview {
            return UsageEntry(date: Date(), snapshot: .placeholder)
        }
        return UsageEntry(date: Date(), snapshot: SnapshotStore.load() ?? .signedOut())
    }

    func timeline(for configuration: UsageWidgetConfiguration, in context: Context) async -> Timeline<UsageEntry> {
        let enabled = configuration.showsMenuBarIcon
        let changed = MenuBarPreference.isEnabled() != enabled
        MenuBarPreference.setEnabled(enabled)
        if enabled {
            MenuBarAgent.launchIfNeeded(arguments: ["--menu-bar"])
        } else if changed {
            MenuBarAgent.launchIfNeeded(arguments: ["--menu-bar-off"])
        }
        let snapshot = await Self.loadSnapshot()
        let next = Date().addingTimeInterval(UsageTiming.refreshInterval)
        return Timeline(entries: [UsageEntry(date: Date(), snapshot: snapshot)], policy: .after(next))
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

enum MenuBarAgent {
    static func launchIfNeeded(arguments: [String]) {
        let bundleID = "org.tx.cursortokenwidget"
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleID }) == false else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: containingAppURL(), configuration: configuration)
    }

    private static func containingAppURL() -> URL {
        var url = Bundle.main.bundleURL
        if url.pathExtension == "appex" {
            url.deleteLastPathComponent()
            url.deleteLastPathComponent()
            url.deleteLastPathComponent()
        }
        return url
    }
}

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CursorUsageWidget", intent: UsageWidgetConfiguration.self, provider: UsageProvider()) { entry in
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
