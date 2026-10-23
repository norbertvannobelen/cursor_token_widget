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

    func testOnDemandCentsAndWarningThreshold() {
        XCTAssertEqual(UsageFormatting.formatCents(0), "$0")
        XCTAssertEqual(UsageFormatting.formatCents(5_000), "$50")
        XCTAssertEqual(UsageFormatting.formatCents(1_250), "$12.50")
        XCTAssertEqual(UsageFormatting.formatCents(nil), "—")
        XCTAssertEqual(UsageFormatting.percentOfLimit(used: 0, limit: 5_000) ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(UsageFormatting.percentOfLimit(used: 4_600, limit: 5_000) ?? 0, 92, accuracy: 0.001)
        XCTAssertNil(UsageFormatting.percentOfLimit(used: 100, limit: nil))
        XCTAssertEqual(UsageFormatting.menuBarIconTone(cursor: 49, other: 83, onDemandPercent: 0, onDemandUsedCents: 0), .normal)
        XCTAssertEqual(UsageFormatting.menuBarIconTone(cursor: 90, other: 10, onDemandPercent: nil, onDemandUsedCents: 0), .normal)
        XCTAssertEqual(UsageFormatting.menuBarIconTone(cursor: 90.5, other: 10, onDemandPercent: nil, onDemandUsedCents: 0), .warning)
        XCTAssertEqual(UsageFormatting.menuBarIconTone(cursor: 96, other: 10, onDemandPercent: nil, onDemandUsedCents: 1), .onDemand)
        XCTAssertFalse(UsageFormatting.exceedsWarning(90))
        XCTAssertFalse(UsageFormatting.exceedsWarning(82.67))
        XCTAssertTrue(UsageFormatting.exceedsWarning(90.5))
        XCTAssertTrue(UsageFormatting.exceedsWarning(96))
        let demand = OnDemandSummary.make(enabled: true, usedCents: 0, limitCents: 5_000)
        XCTAssertEqual(demand?.usageText, "$0")
        XCTAssertEqual(demand?.limitText, "$50")
        XCTAssertEqual(demand?.pairText, "$0/$50")
        XCTAssertNil(OnDemandSummary.make(enabled: nil, usedCents: nil, limitCents: nil))
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

    func testOnDemandUsageDecodesCentsAndNullLimit() throws {
        let json = """
        {"individualUsage":{"onDemand":{"enabled":true,"used":0,"limit":5000,"remaining":5000}}}
        """.data(using: .utf8)!
        let summary = try JSONDecoder().decode(UsageSummaryResponse.self, from: json)
        XCTAssertEqual(summary.individualUsage?.onDemand?.enabled, true)
        XCTAssertEqual(summary.individualUsage?.onDemand?.used?.value, 0)
        XCTAssertEqual(summary.individualUsage?.onDemand?.limit?.value, 5000)

        let unlimited = """
        {"individualUsage":{"onDemand":{"enabled":true,"used":1250,"limit":null}}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UsageSummaryResponse.self, from: unlimited)
        XCTAssertEqual(decoded.individualUsage?.onDemand?.used?.value, 1250)
        XCTAssertNil(decoded.individualUsage?.onDemand?.limit?.value)
        let display = OnDemandSummary.make(enabled: true, usedCents: 1250, limitCents: nil)
        XCTAssertEqual(display?.limitText, "No limit")
        XCTAssertEqual(display?.pairText, "$12.50")
        XCTAssertNil(display?.percent)
    }

    func testAggregatedTokensSumStringAndMissingCacheWrite() throws {
        let json = """
        {"totalInputTokens":"10","totalOutputTokens":2,"totalCacheReadTokens":"30","aggregations":[]}
        """.data(using: .utf8)!
        let usage = try JSONDecoder().decode(AggregatedUsage.self, from: json)
        XCTAssertEqual(usage.totalTokens, 42)
    }

    func testMenuBarPreferenceStoresAFlag() {
        XCTAssertFalse(MenuBarPreference.isEnabled(stored: nil))
        XCTAssertFalse(MenuBarPreference.isEnabled(stored: "0"))
        XCTAssertTrue(MenuBarPreference.isEnabled(stored: "1"))
        XCTAssertEqual(MenuBarPreference.storedValue(enabled: true), "1")
        XCTAssertEqual(MenuBarPreference.storedValue(enabled: false), "0")
    }

    func testAggregatedTokensFallBackToRows() throws {
        let json = """
        {"aggregations":[{"inputTokens":"4","outputTokens":"1","cacheReadTokens":"5"}]}
        """.data(using: .utf8)!
        let usage = try JSONDecoder().decode(AggregatedUsage.self, from: json)
        XCTAssertEqual(usage.totalTokens, 10)
    }
}
