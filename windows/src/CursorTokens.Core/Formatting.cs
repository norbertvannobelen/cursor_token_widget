using System.Globalization;

namespace CursorTokens;

public static class Formatting
{
    public const string EmDash = "\u2014";

    public static int RoundHalfAway(double value)
    {
        if (double.IsNaN(value) || double.IsInfinity(value))
        {
            return 0;
        }

        return value >= 0
            ? (int)Math.Floor(value + 0.5)
            : (int)Math.Ceiling(value - 0.5);
    }

    public static string FormatPercent(double? value)
    {
        if (value is not { } number || !double.IsFinite(number))
        {
            return EmDash;
        }

        return RoundHalfAway(number).ToString(CultureInfo.InvariantCulture) + "%";
    }

    public static double BarFraction(double? value)
    {
        if (value is not { } number || !double.IsFinite(number))
        {
            return 0;
        }

        return Math.Clamp(number, 0, 100) / 100.0;
    }

    public static bool ExceedsWarning(double? value)
    {
        if (value is not { } number || !double.IsFinite(number))
        {
            return false;
        }

        return RoundHalfAway(number) > 90;
    }

    public static double? PercentOfLimit(int? used, int? limit)
    {
        if (limit is null or <= 0)
        {
            return null;
        }

        return (used ?? 0) / (double)limit.Value * 100.0;
    }

    public static string FormatCents(int? cents)
    {
        if (cents is null)
        {
            return EmDash;
        }

        var sign = cents.Value < 0 ? "-" : "";
        var absolute = Math.Abs(cents.Value);
        if (absolute % 100 == 0)
        {
            return $"{sign}${absolute / 100}";
        }

        return sign + "$" + (absolute / 100.0).ToString("0.00", CultureInfo.InvariantCulture);
    }

    public static string FormatTokenCount(long? value)
    {
        if (value is null)
        {
            return EmDash;
        }

        var scaled = (double)Math.Max(value.Value, 0);
        var suffixes = new[] { "", "K", "M", "B", "T" };
        var index = 0;
        while (scaled >= 1000 && index < suffixes.Length - 1)
        {
            scaled /= 1000;
            index++;
        }

        if (index < suffixes.Length - 1 && RoundHalfAway(scaled * 10) / 10.0 >= 1000)
        {
            scaled /= 1000;
            index++;
        }

        if (index == 0)
        {
            return RoundHalfAway(scaled).ToString(CultureInfo.InvariantCulture);
        }

        var tenths = RoundHalfAway(scaled * 10);
        var whole = tenths / 10;
        var frac = tenths % 10;
        if (frac == 0)
        {
            return $"{whole}{suffixes[index]}";
        }

        return $"{whole}.{frac}{suffixes[index]}";
    }

    public static string? MembershipLabel(string? raw)
    {
        if (raw is null)
        {
            return null;
        }

        var key = raw.ToLowerInvariant();
        if (key is "pro_plus" or "pro-plus" or "plus")
        {
            return "Pro+";
        }

        if (key == "pro")
        {
            return "Pro";
        }

        if (key == "ultra")
        {
            return "Ultra";
        }

        if (key is "enterprise" or "business" or "team")
        {
            return "Team";
        }

        if (key is "free" or "hobby")
        {
            return "Free";
        }

        return TitleWords(raw);
    }

    public static DateTimeOffset WindowStart(int daysAgo, DateTimeOffset now)
    {
        var local = now.ToOffset(now.Offset);
        var startToday = new DateTimeOffset(local.Year, local.Month, local.Day, 0, 0, 0, local.Offset);
        return startToday.AddDays(-daysAgo);
    }

    public static string Clock(DateTimeOffset moment)
    {
        var local = moment.ToLocalTime();
        var hour = local.ToString("hh", CultureInfo.InvariantCulture).TrimStart('0');
        if (hour.Length == 0)
        {
            hour = "0";
        }

        var minute = local.ToString("mm", CultureInfo.InvariantCulture);
        var ampm = local.ToString("tt", CultureInfo.InvariantCulture);
        return $"{hour}:{minute} {ampm}";
    }

    private static string TitleWords(string raw)
    {
        var words = raw.Replace('_', ' ').Split(' ', StringSplitOptions.RemoveEmptyEntries);
        for (var index = 0; index < words.Length; index++)
        {
            var word = words[index];
            words[index] = char.ToUpperInvariant(word[0]) + word[1..].ToLowerInvariant();
        }

        return string.Join(' ', words);
    }
}
