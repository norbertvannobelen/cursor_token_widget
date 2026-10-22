using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CursorTokens;

public sealed class Meter
{
    public string Text { get; init; } = Formatting.EmDash;

    public double Fraction { get; init; }

    public bool Warning { get; init; }

    public static Meter FromPercent(double? percent)
    {
        return new Meter
        {
            Text = Formatting.FormatPercent(percent),
            Fraction = Formatting.BarFraction(percent),
            Warning = Formatting.ExceedsWarning(percent),
        };
    }
}

public sealed class OnDemandDisplay
{
    public string UsageText { get; init; } = Formatting.EmDash;

    public string LimitText { get; init; } = Formatting.EmDash;

    public string PairText { get; init; } = Formatting.EmDash;

    public double Fraction { get; init; }

    public bool HasBar { get; init; }

    public bool Warning { get; init; }

    public static OnDemandDisplay? From(bool? enabled, int? usedCents, int? limitCents)
    {
        if (enabled is null && usedCents is null && limitCents is null)
        {
            return null;
        }

        var usageText = Formatting.FormatCents(usedCents ?? 0);
        string limitText;
        string pairText;
        if (limitCents is not null)
        {
            limitText = Formatting.FormatCents(limitCents);
            pairText = $"{usageText}/{limitText}";
        }
        else if (enabled is false)
        {
            limitText = "Off";
            pairText = usageText;
        }
        else
        {
            limitText = "No limit";
            pairText = usageText;
        }

        var percent = Formatting.PercentOfLimit(usedCents, limitCents);
        return new OnDemandDisplay
        {
            UsageText = usageText,
            LimitText = limitText,
            PairText = pairText,
            Fraction = percent is null ? 0 : Formatting.BarFraction(percent),
            HasBar = percent is not null,
            Warning = Formatting.ExceedsWarning(percent),
        };
    }
}

public sealed class TokenTexts
{
    public string Today { get; init; } = Formatting.EmDash;

    public string Week { get; init; } = Formatting.EmDash;

    public string Month { get; init; } = Formatting.EmDash;
}

public sealed class UsageSnapshot
{
    public bool SignedIn { get; init; }

    public string Email { get; init; } = "";

    public string Membership { get; init; } = "";

    public Meter Cursor { get; init; } = new();

    public Meter Other { get; init; } = new();

    public OnDemandDisplay? OnDemand { get; init; }

    public TokenTexts Tokens { get; init; } = new();

    public string UpdatedAt { get; init; } = "";

    public string UpdatedText { get; init; } = "";

    public string? Error { get; set; }

    public static UsageSnapshot Create(
        bool signedIn,
        double? cursorPercent = null,
        double? otherPercent = null,
        long? todayTokens = null,
        long? weekTokens = null,
        long? monthTokens = null,
        bool? onDemandEnabled = null,
        int? onDemandUsedCents = null,
        int? onDemandLimitCents = null,
        string? membership = null,
        string? email = null,
        DateTimeOffset? updatedAt = null,
        string? error = null)
    {
        var moment = updatedAt ?? DateTimeOffset.Now;
        return new UsageSnapshot
        {
            SignedIn = signedIn,
            Email = email ?? "",
            Membership = Formatting.MembershipLabel(membership) ?? "",
            Cursor = Meter.FromPercent(cursorPercent),
            Other = Meter.FromPercent(otherPercent),
            OnDemand = OnDemandDisplay.From(onDemandEnabled, onDemandUsedCents, onDemandLimitCents),
            Tokens = new TokenTexts
            {
                Today = Formatting.FormatTokenCount(todayTokens),
                Week = Formatting.FormatTokenCount(weekTokens),
                Month = Formatting.FormatTokenCount(monthTokens),
            },
            UpdatedAt = moment.ToString("o", CultureInfo.InvariantCulture),
            UpdatedText = Formatting.Clock(moment),
            Error = error,
        };
    }

    public static UsageSnapshot SignedOut(DateTimeOffset? updatedAt = null, string? error = null)
    {
        return Create(signedIn: false, updatedAt: updatedAt, error: error);
    }
}

public static class SnapshotJson
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
        WriteIndented = true,
    };
}
