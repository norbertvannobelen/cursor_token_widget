import Foundation

struct UsageSnapshot: Codable, Equatable {
    var isSignedIn: Bool
    var cursorModelsPercent: Double?
    var otherModelsPercent: Double?
    var todayTokens: Int?
    var weekTokens: Int?
    var monthTokens: Int?
    var membership: String?
    var email: String?
    var updatedAt: Date
    var error: String?

    var membershipLabel: String? {
        MembershipLabel.display(membership)
    }

    var menuTitle: String {
        guard isSignedIn,
              let cursorModelsPercent,
              let otherModelsPercent else {
            return "Cursor"
        }
        return "\(UsageFormatting.formatPercent(cursorModelsPercent)) \(UsageFormatting.formatPercent(otherModelsPercent))"
    }

    static func signedOut(error: String? = nil) -> UsageSnapshot {
        UsageSnapshot(
            isSignedIn: false,
            cursorModelsPercent: nil,
            otherModelsPercent: nil,
            todayTokens: nil,
            weekTokens: nil,
            monthTokens: nil,
            membership: nil,
            email: nil,
            updatedAt: Date(),
            error: error
        )
    }

    static func emptySignedIn() -> UsageSnapshot {
        UsageSnapshot(
            isSignedIn: true,
            cursorModelsPercent: nil,
            otherModelsPercent: nil,
            todayTokens: nil,
            weekTokens: nil,
            monthTokens: nil,
            membership: nil,
            email: nil,
            updatedAt: .distantPast,
            error: nil
        )
    }

    static let placeholder = UsageSnapshot(
        isSignedIn: true,
        cursorModelsPercent: 41,
        otherModelsPercent: 83,
        todayTokens: 30_300_000,
        weekTokens: 909_200_000,
        monthTokens: 1_280_000_000,
        membership: "pro_plus",
        email: nil,
        updatedAt: Date(),
        error: nil
    )
}
