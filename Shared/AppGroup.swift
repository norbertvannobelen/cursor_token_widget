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
            if let data = readBounded(url), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    static func remove(named name: String) {
        for url in candidateURLs(named: name) {
            if directoryOverride != nil {
                try? FileManager.default.removeItem(at: url)
            } else {
                _ = performBounded { try? FileManager.default.removeItem(at: url) }
            }
        }
    }

    static func writeData(_ data: Data, named name: String, permissions: Int? = nil) {
        for url in candidateURLs(named: name) {
            let wrote = performBounded {
                let directory = url.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    return
                }
                if let permissions {
                    try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
                }
                removexattr(url.path, "com.apple.quarantine", 0)
            }
            if !wrote {
                return
            }
        }
    }

    /// A stuck group container must not freeze the menu bar process. After one slow
    /// attempt, later calls skip the files and callers use the keychain copy.
    private static let stateLock = NSLock()
    private static var fileAccessDisabled = false
    private static let fileAccessTimeout: TimeInterval = 0.35

    private static func readBounded(_ url: URL) -> Data? {
        if directoryOverride != nil {
            return try? Data(contentsOf: url)
        }
        let box = DataBox()
        let finished = performBounded {
            box.set(try? Data(contentsOf: url))
        }
        return finished ? box.get() : nil
    }

    private static func performBounded(_ work: @escaping () -> Void) -> Bool {
        if directoryOverride != nil {
            work()
            return true
        }
        stateLock.lock()
        let disabled = fileAccessDisabled
        stateLock.unlock()
        if disabled {
            return false
        }
        let box = DataBox()
        DispatchQueue.global(qos: .userInitiated).async {
            work()
            box.set(Data())
        }
        let deadline = Date().addingTimeInterval(fileAccessTimeout)
        while Date() < deadline {
            if box.get() != nil {
                return true
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        stateLock.lock()
        fileAccessDisabled = true
        stateLock.unlock()
        return false
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
        return urls
    }

    private final class DataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var data: Data?

        func set(_ data: Data?) {
            lock.lock()
            self.data = data ?? Data()
            lock.unlock()
        }

        func get() -> Data? {
            lock.lock()
            defer { lock.unlock() }
            return data
        }
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
