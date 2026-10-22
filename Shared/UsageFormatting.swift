import Foundation

enum UsageFormatting {
    static func formatPercent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    static func barFraction(_ value: Double?) -> Double {
        guard let value, value.isFinite else { return 0 }
        return min(max(value, 0), 100) / 100
    }

    /// Included and on-demand bars turn red once the displayed percent is above 90.
    static func exceedsWarning(_ percent: Double?) -> Bool {
        guard let percent, percent.isFinite else { return false }
        return Int(percent.rounded()) > 90
    }

    /// `used` and `limit` are cent amounts. A missing or non-positive limit has no bar.
    static func percentOfLimit(used: Int?, limit: Int?) -> Double? {
        guard let limit, limit > 0 else { return nil }
        return Double(used ?? 0) / Double(limit) * 100
    }

    static func formatCents(_ cents: Int?) -> String {
        guard let cents else { return "—" }
        let sign = cents < 0 ? "-" : ""
        let absolute = abs(cents)
        if absolute % 100 == 0 {
            return "\(sign)$\(absolute / 100)"
        }
        return sign + String(format: "$%.2f", Double(absolute) / 100)
    }

    static func formatTokenCount(_ value: Int?) -> String {
        guard let value else { return "—" }
        let absolute = Double(max(value, 0))
        var scaled = absolute
        let suffixes = ["", "K", "M", "B", "T"]
        var index = 0
        while scaled >= 1000, index < suffixes.count - 1 {
            scaled /= 1000
            index += 1
        }
        if index < suffixes.count - 1, (scaled * 10).rounded() / 10 >= 1000 {
            scaled /= 1000
            index += 1
        }
        if index == 0 {
            return String(Int(scaled.rounded()))
        }
        let text = String(format: "%.1f", scaled)
        let trimmed = text.hasSuffix(".0") ? String(text.dropLast(2)) : text
        return trimmed + suffixes[index]
    }
}

enum MembershipLabel {
    static func display(_ raw: String?) -> String? {
        switch raw?.lowercased() {
        case "pro_plus", "pro-plus", "plus":
            return "Pro+"
        case "pro":
            return "Pro"
        case "ultra":
            return "Ultra"
        case "enterprise", "business", "team":
            return "Team"
        case "free", "hobby":
            return "Free"
        case let other?:
            return other.replacingOccurrences(of: "_", with: " ").capitalized
        case nil:
            return nil
        }
    }
}

enum DateWindows {
    /// Start of the local calendar day `daysAgo` days before `now`.
    /// A 7-day window uses `daysAgo: 6` so today is included, matching the dashboard.
    static func start(daysAgo: Int, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let startToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -daysAgo, to: startToday) ?? startToday
    }
}
