import Foundation

enum SessionCookie {
    static func normalizeStored(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "WorkosCursorSessionToken="
        if trimmed.hasPrefix(prefix) {
            trimmed = String(trimmed.dropFirst(prefix.count))
        }
        let decoded = decodeFully(trimmed)
        if decoded.contains("::") {
            return decoded
        }
        if let subject = try? JWT.subject(from: decoded) {
            return "\(subject)::\(decoded)"
        }
        return decoded
    }

    static func headerValue(from stored: String) -> String {
        let normalized = normalizeStored(stored)
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = normalized.addingPercentEncoding(withAllowedCharacters: allowed) ?? normalized
        return "WorkosCursorSessionToken=\(encoded)"
    }

    private static func decodeFully(_ value: String) -> String {
        var current = value
        for _ in 0..<2 {
            guard let decoded = current.removingPercentEncoding, decoded != current else { break }
            current = decoded
        }
        return current
    }
}

enum JWT {
    enum Error: Swift.Error {
        case malformed
        case missingSubject
    }

    static func subject(from token: String) throws -> String {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { throw Error.malformed }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder != 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: payload),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subject = json["sub"] as? String,
              !subject.isEmpty else {
            throw Error.missingSubject
        }
        return subject
    }
}
