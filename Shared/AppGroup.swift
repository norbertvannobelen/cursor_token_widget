import Foundation

enum AppGroup {
    static let identifier = "group.org.tx.cursortokenwidget"

    static var directoryOverride: URL?

    static func containerURL() -> URL? {
        if let directoryOverride {
            return directoryOverride
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

enum UsageTiming {
    static let refreshInterval: TimeInterval = 5 * 60
    /// Widget timeline reloads triggered by the app should reuse a snapshot just written.
    static let cacheFreshness: TimeInterval = 90
}
