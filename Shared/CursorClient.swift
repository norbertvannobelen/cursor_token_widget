import Foundation
import os

private let usageLogger = Logger(subsystem: "org.tx.cursortokenwidget", category: "usage")

enum CursorAPIError: Error {
    case unauthorized
    case http(Int)
    case badResponse
}

struct FlexInt: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = 0
            return
        }
        if let intValue = try? container.decode(Int.self) {
            value = intValue
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            value = Int(doubleValue.rounded())
            return
        }
        if let stringValue = try? container.decode(String.self), let parsed = Double(stringValue) {
            value = Int(parsed.rounded())
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a token count")
    }
}

struct FlexDouble: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = 0
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
            return
        }
        if let intValue = try? container.decode(Int.self) {
            value = Double(intValue)
            return
        }
        if let stringValue = try? container.decode(String.self), let parsed = Double(stringValue) {
            value = parsed
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a percent")
    }
}

struct UsageSummaryResponse: Decodable {
    var membershipType: String?
    var individualUsage: IndividualUsage?

    struct IndividualUsage: Decodable {
        var plan: Plan?
    }

    struct Plan: Decodable {
        var autoPercentUsed: FlexDouble?
        var apiPercentUsed: FlexDouble?
    }
}

struct ProfileResponse: Decodable {
    var email: String?
}

struct ModelAggregation: Decodable {
    var inputTokens: FlexInt?
    var outputTokens: FlexInt?
    var cacheWriteTokens: FlexInt?
    var cacheReadTokens: FlexInt?

    var totalTokens: Int {
        (inputTokens?.value ?? 0)
            + (outputTokens?.value ?? 0)
            + (cacheWriteTokens?.value ?? 0)
            + (cacheReadTokens?.value ?? 0)
    }
}

struct AggregatedUsage: Decodable {
    var totalInputTokens: FlexInt?
    var totalOutputTokens: FlexInt?
    var totalCacheWriteTokens: FlexInt?
    var totalCacheReadTokens: FlexInt?
    var aggregations: [ModelAggregation]?

    var totalTokens: Int {
        let parts = [totalInputTokens, totalOutputTokens, totalCacheWriteTokens, totalCacheReadTokens]
        if parts.contains(where: { $0 != nil }) {
            return parts.reduce(0) { $0 + ($1?.value ?? 0) }
        }
        return (aggregations ?? []).reduce(0) { $0 + $1.totalTokens }
    }
}

struct CursorClient {
    var sessionValue: String
    var urlSession: URLSession = CursorClient.makeSession()

    func fetchSummary() async throws -> UsageSummaryResponse {
        try await send(url: Self.summaryURL, method: "GET", body: nil)
    }

    func fetchEmail() async throws -> String? {
        let profile: ProfileResponse = try await send(url: Self.profileURL, method: "GET", body: nil)
        return profile.email
    }

    func fetchTotalTokens(from start: Date, to end: Date) async throws -> Int {
        let body: [String: Any] = [
            "teamId": -1,
            "startDate": Int64(start.timeIntervalSince1970 * 1000),
            "endDate": Int64(end.timeIntervalSince1970 * 1000),
        ]
        let usage: AggregatedUsage = try await send(url: Self.aggregatedURL, method: "POST", body: body)
        return usage.totalTokens
    }

    private func send<Response: Decodable>(
        url: URL,
        method: String,
        body: [String: Any]?
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(SessionCookie.headerValue(from: sessionValue), forHTTPHeaderField: "Cookie")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.setValue("https://cursor.com/dashboard?tab=usage", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CursorAPIError.badResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw CursorAPIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            usageLogger.error("Cursor API \(method, privacy: .public) \(url.path, privacy: .public) returned \(http.statusCode, privacy: .public)")
            throw CursorAPIError.http(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            usageLogger.error("Cursor API decode failed for \(url.path, privacy: .public)")
            throw CursorAPIError.badResponse
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    private static let summaryURL = URL(string: "https://cursor.com/api/usage-summary")!
    private static let profileURL = URL(string: "https://cursor.com/api/auth/me")!
    private static let aggregatedURL = URL(string: "https://cursor.com/api/dashboard/get-aggregated-usage-events")!
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15"
}
