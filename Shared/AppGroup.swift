import Darwin
import Foundation

enum AppGroup {
    static let identifier = "group.org.tx.cursortokenwidget"

    static var directoryOverride: URL?

    static func containerURL() -> URL? {
        if let directoryOverride {
            return directoryOverride
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) ?? realGroupDirectory()
    }

    static func readData(named name: String) -> Data? {
        for url in candidateURLs(named: name) {
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    static func remove(named name: String) {
        for url in candidateURLs(named: name) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func writeData(_ data: Data, named name: String, permissions: Int? = nil) {
        for url in candidateURLs(named: name) {
            let directory = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                continue
            }
            if let permissions {
                try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
            }
            removexattr(url.path, "com.apple.quarantine", 0)
        }
    }

    private static func candidateURLs(named name: String) -> [URL] {
        if let directoryOverride {
            return [directoryOverride.appendingPathComponent(name)]
        }
        var urls: [URL] = []
        func append(_ directory: URL?) {
            guard let directory else { return }
            let url = directory.appendingPathComponent(name)
            if !urls.contains(url) {
                urls.append(url)
            }
        }
        append(realGroupDirectory())
        append(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier))
        return urls
    }

    /// The sandbox home is the app container, so shared files are opened from the real home.
    private static func realGroupDirectory() -> URL? {
        guard let passwd = getpwuid(getuid()) else { return nil }
        let home = String(cString: passwd.pointee.pw_dir)
        return URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("Library/Group Containers/\(identifier)", isDirectory: true)
    }
}

enum UsageTiming {
    static let refreshInterval: TimeInterval = 5 * 60
    /// Widget timeline reloads triggered by the app should reuse a snapshot just written.
    static let cacheFreshness: TimeInterval = 90
}
