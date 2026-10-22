import XCTest

final class UsageFormattingTests: XCTestCase {
    func testPercentRoundingMatchesDashboard() {
        XCTAssertEqual(UsageFormatting.formatPercent(41.2075), "41%")
        XCTAssertEqual(UsageFormatting.formatPercent(82.672727), "83%")
        XCTAssertEqual(UsageFormatting.formatPercent(nil), "—")
    }

    func testTokenCountsUseDashboardScale() {
        XCTAssertEqual(UsageFormatting.formatTokenCount(30_284_186), "30.3M")
        XCTAssertEqual(UsageFormatting.formatTokenCount(909_200_000), "909.2M")
        XCTAssertEqual(UsageFormatting.formatTokenCount(1_279_903_814), "1.3B")
        XCTAssertEqual(UsageFormatting.formatTokenCount(999_999), "1M")
        XCTAssertEqual(UsageFormatting.formatTokenCount(12), "12")
        XCTAssertEqual(UsageFormatting.formatTokenCount(nil), "—")
    }

    func testBarFractionClamps() {
        XCTAssertEqual(UsageFormatting.barFraction(50), 0.5, accuracy: 0.001)
        XCTAssertEqual(UsageFormatting.barFraction(140), 1, accuracy: 0.001)
        XCTAssertEqual(UsageFormatting.barFraction(nil), 0, accuracy: 0.001)
    }

    func testSevenDayWindowIncludesToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_761_148_800)
        let start = DateWindows.start(daysAgo: 6, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: today).day
        XCTAssertEqual(days, 6)
    }

    func testMembershipLabels() {
        XCTAssertEqual(MembershipLabel.display("pro_plus"), "Pro+")
        XCTAssertEqual(MembershipLabel.display("pro"), "Pro")
        XCTAssertEqual(MembershipLabel.display("ultra"), "Ultra")
    }
}

final class SessionCookieTests: XCTestCase {
    func testSessionCookieEncodesSubjectSeparator() {
        let header = SessionCookie.headerValue(from: "google-oauth2|abc::aaa.bbb.ccc")
        XCTAssertTrue(header.hasPrefix("WorkosCursorSessionToken="))
        XCTAssertTrue(header.contains("%7C"))
        XCTAssertTrue(header.contains("%3A%3A"))
        XCTAssertFalse(header.contains("::"))
    }

    func testRawJWTGainsSubject() {
        let payload = Data("{\"sub\":\"google-oauth2|abc\"}".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let token = "eyJhbGciOiJIUzI1NiJ9.\(payload).sig"
        let stored = SessionCookie.normalizeStored(token)
        XCTAssertTrue(stored.hasPrefix("google-oauth2|abc::"))
        XCTAssertEqual(try JWT.subject(from: token), "google-oauth2|abc")
    }
}

final class CursorDecodingTests: XCTestCase {
    func testSummaryPercents() throws {
        let json = """
        {"membershipType":"pro_plus","individualUsage":{"plan":{"autoPercentUsed":41.2075,"apiPercentUsed":82.67}}}
        """.data(using: .utf8)!
        let summary = try JSONDecoder().decode(UsageSummaryResponse.self, from: json)
        XCTAssertEqual(summary.membershipType, "pro_plus")
        XCTAssertEqual(summary.individualUsage?.plan?.autoPercentUsed?.value ?? 0, 41.2075, accuracy: 0.001)
        XCTAssertEqual(summary.individualUsage?.plan?.apiPercentUsed?.value ?? 0, 82.67, accuracy: 0.001)
    }

    func testAggregatedTokensSumStringAndMissingCacheWrite() throws {
        let json = """
        {"totalInputTokens":"10","totalOutputTokens":2,"totalCacheReadTokens":"30","aggregations":[]}
        """.data(using: .utf8)!
        let usage = try JSONDecoder().decode(AggregatedUsage.self, from: json)
        XCTAssertEqual(usage.totalTokens, 42)
    }

    func testAggregatedTokensFallBackToRows() throws {
        let json = """
        {"aggregations":[{"inputTokens":"4","outputTokens":"1","cacheReadTokens":"5"}]}
        """.data(using: .utf8)!
        let usage = try JSONDecoder().decode(AggregatedUsage.self, from: json)
        XCTAssertEqual(usage.totalTokens, 10)
    }
}
