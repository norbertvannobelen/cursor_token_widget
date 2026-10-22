import Foundation

enum SnapshotStore {
    private static let fileName = "snapshot.json"
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func save(_ snapshot: UsageSnapshot) {
        guard let url = fileURL() else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> UsageSnapshot? {
        guard let url = fileURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }

    private static func fileURL() -> URL? {
        AppGroup.containerURL()?.appendingPathComponent(fileName)
    }
}
