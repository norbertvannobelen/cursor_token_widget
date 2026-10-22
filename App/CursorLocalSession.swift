import Foundation
import os
import SQLite3

private let sessionLogger = Logger(subsystem: "org.tx.cursortokenwidget", category: "session")

enum LocalSessionError: LocalizedError {
    case cursorNotInstalled
    case unreadable
    case notSignedIn
    case malformedToken

    var errorDescription: String? {
        switch self {
        case .cursorNotInstalled:
            return "Cursor doesn't look installed for this Mac user."
        case .unreadable:
            return "Couldn't read the Cursor session. Sign in with the browser instead."
        case .notSignedIn:
            return "Cursor is installed, but no account is signed in."
        case .malformedToken:
            return "The Cursor session on this Mac couldn't be used. Sign in with the browser instead."
        }
    }
}

enum CursorLocalSession {
    /// Sandboxed apps see `homeDirectoryForCurrentUser` inside their container.
    /// The Cursor database lives in the real user home, which the app entitlement allows.
    private static func realHomeDirectory() -> URL {
        if let password = getpwuid(getuid()), let directory = password.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static func loadSession() throws -> String {
        let databaseURL = realHomeDirectory()
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(databaseURL.path, &database, flags, nil) != SQLITE_OK || database == nil {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            sessionLogger.error("Cursor session database open failed: \(message, privacy: .public)")
            if let database { sqlite3_close(database) }
            throw database == nil && !FileManager.default.fileExists(atPath: databaseURL.path)
                ? LocalSessionError.cursorNotInstalled
                : LocalSessionError.unreadable
        }
        guard let database else {
            throw LocalSessionError.unreadable
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1;"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(database))
            sessionLogger.error("Cursor session query failed: \(message, privacy: .public)")
            throw LocalSessionError.unreadable
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw LocalSessionError.notSignedIn
        }
        guard let raw = sqlite3_column_text(statement, 0) else {
            throw LocalSessionError.notSignedIn
        }
        let token = String(cString: UnsafePointer<CChar>(OpaquePointer(raw)))
        guard !token.isEmpty else {
            throw LocalSessionError.notSignedIn
        }
        do {
            let subject = try JWT.subject(from: token)
            return "\(subject)::\(token)"
        } catch {
            throw LocalSessionError.malformedToken
        }
    }
}
