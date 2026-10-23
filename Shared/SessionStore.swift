import Foundation

enum SessionStore {
    private static let fileName = "session.txt"
    private static let account = "session"

    static func save(_ session: String) {
        let data = Data(session.utf8)
        AppGroup.writeData(data, named: fileName, permissions: 0o600)
        KeychainStore.save(data, account: account)
    }

    static func load() -> String? {
        if let value = string(from: KeychainStore.load(account: account)) {
            return value
        }
        guard let value = string(from: AppGroup.readData(named: fileName)) else { return nil }
        KeychainStore.save(Data(value.utf8), account: account)
        return value
    }

    static func delete() {
        AppGroup.remove(named: fileName)
        KeychainStore.delete(account: account)
    }

    private static func string(from data: Data?) -> String? {
        guard let data, let value = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
