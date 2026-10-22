import Foundation

enum SnapshotStore {
    private static let fileName = "snapshot.json"
    private static let account = "snapshot"
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
        guard let data = try? encoder.encode(snapshot) else { return }
        AppGroup.writeData(data, named: fileName)
        KeychainStore.save(data, account: account)
    }

    static func load() -> UsageSnapshot? {
        if let data = AppGroup.readData(named: fileName),
           let snapshot = try? decoder.decode(UsageSnapshot.self, from: data) {
            KeychainStore.save(data, account: account)
            return snapshot
        }
        guard let data = KeychainStore.load(account: account) else { return nil }
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }
}
