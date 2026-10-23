import SwiftUI

struct UsageWidgetView: View {
    var snapshot: UsageSnapshot
    var accented: Bool = false

    var body: some View {
        Group {
            if snapshot.isSignedIn {
                signedIn
            } else {
                signedOut
            }
        }
        .padding(10)
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Usage")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 4)
                if let membership = snapshot.membershipLabel {
                    Text(membership)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            CompactMeter(
                title: "Cursor",
                value: UsageFormatting.formatPercent(snapshot.cursorModelsPercent),
                percent: snapshot.cursorModelsPercent,
                tint: .blue,
                accented: accented
            )
            CompactMeter(
                title: "Other",
                value: UsageFormatting.formatPercent(snapshot.otherModelsPercent),
                percent: snapshot.otherModelsPercent,
                tint: .primary.opacity(0.55),
                accented: accented
            )
            if let demand = snapshot.onDemand {
                CompactMeter(
                    title: "On-demand",
                    value: demand.pairText,
                    percent: demand.percent,
                    tint: .orange,
                    accented: accented
                )
            }
            Spacer(minLength: 2)
            VStack(spacing: 2) {
                CompactStat(label: "Today", tokens: snapshot.todayTokens)
                CompactStat(label: "7 days", tokens: snapshot.weekTokens)
                CompactStat(label: "30 days", tokens: snapshot.monthTokens)
            }
        }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cursor")
                .font(.system(size: 13, weight: .semibold))
            Text("Sign in to load model allowance and token use.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct CompactMeter: View {
    var title: String
    var value: String
    var percent: Double?
    var tint: Color
    var accented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(barFill)
                        .frame(width: max(0, geo.size.width * UsageFormatting.barFraction(percent)))
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value)")
    }

    private var barFill: AnyShapeStyle {
        if UsageFormatting.exceedsWarning(percent) {
            return AnyShapeStyle(.red)
        }
        if accented {
            return AnyShapeStyle(.primary)
        }
        return AnyShapeStyle(tint)
    }
}

private struct CompactStat: View {
    var label: String
    var tokens: Int?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(UsageFormatting.formatTokenCount(tokens))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.system(size: 11, design: .rounded))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(UsageFormatting.formatTokenCount(tokens)) tokens")
    }
}
