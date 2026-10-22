import Foundation

struct OnDemandSummary: Equatable {
    var usageText: String
    var limitText: String
    var pairText: String
    var percent: Double?

    static func make(enabled: Bool?, usedCents: Int?, limitCents: Int?) -> OnDemandSummary? {
        guard enabled != nil || usedCents != nil || limitCents != nil else { return nil }
        let usageText = UsageFormatting.formatCents(usedCents ?? 0)
        let limitText: String
        if let limitCents {
            limitText = UsageFormatting.formatCents(limitCents)
        } else if enabled == false {
            limitText = "Off"
        } else {
            limitText = "No limit"
        }
        let pairText = limitCents == nil ? usageText : "\(usageText)/\(limitText)"
        return OnDemandSummary(
            usageText: usageText,
            limitText: limitText,
            pairText: pairText,
            percent: UsageFormatting.percentOfLimit(used: usedCents, limit: limitCents)
        )
    }
}

struct UsageSnapshot: Codable, Equatable {
    var isSignedIn: Bool
    var cursorModelsPercent: Double?
    var otherModelsPercent: Double?
    var todayTokens: Int?
    var weekTokens: Int?
    var monthTokens: Int?
    var onDemandEnabled: Bool? = nil
    var onDemandUsedCents: Int? = nil
    var onDemandLimitCents: Int? = nil
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

    var onDemand: OnDemandSummary? {
        OnDemandSummary.make(
            enabled: onDemandEnabled,
            usedCents: onDemandUsedCents,
            limitCents: onDemandLimitCents
        )
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
        onDemandEnabled: true,
        onDemandUsedCents: 1_800,
        onDemandLimitCents: 5_000,
        membership: "pro_plus",
        email: nil,
        updatedAt: Date(),
        error: nil
    )
}
