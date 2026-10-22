using System.Text.Json;

namespace CursorTokens;

public static class WidgetCard
{
    public const string StayVerb = "stay";

    public static string Build(UsageSnapshot snapshot)
    {
        var body = new List<object>();
        if (!snapshot.SignedIn)
        {
            body.Add(Text("Cursor", weight: "Bolder"));
            body.Add(Text("Open Cursor Tokens and sign in to see allowance and token use.", wrap: true));
            if (!string.IsNullOrEmpty(snapshot.Error))
            {
                body.Add(Text(snapshot.Error, subtle: true, size: "Small", wrap: true));
            }
        }
        else
        {
            body.Add(Header(snapshot.Membership));
            body.Add(Row("Cursor models", snapshot.Cursor.Text));
            body.Add(Bar(snapshot.Cursor.Fraction, snapshot.Cursor.Warning, "accent"));
            body.Add(Row("Other models", snapshot.Other.Text));
            body.Add(Bar(snapshot.Other.Fraction, snapshot.Other.Warning, "warning"));
            if (snapshot.OnDemand is { } demand)
            {
                body.Add(Row("On-demand", demand.PairText));
                if (demand.HasBar)
                {
                    body.Add(Bar(demand.Fraction, demand.Warning, "good"));
                }
            }

            body.Add(Row("Today", snapshot.Tokens.Today));
            body.Add(Row("7 days", snapshot.Tokens.Week));
            body.Add(Row("30 days", snapshot.Tokens.Month));
            if (!string.IsNullOrEmpty(snapshot.UpdatedText))
            {
                body.Add(Text("Updated " + snapshot.UpdatedText, subtle: true, size: "Small"));
            }

            if (!string.IsNullOrEmpty(snapshot.Error))
            {
                body.Add(Text(snapshot.Error, subtle: true, size: "Small", wrap: true));
            }
        }

        var card = new Dictionary<string, object>
        {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.5",
            ["selectAction"] = new Dictionary<string, object>
            {
                ["type"] = "Action.Execute",
                ["verb"] = StayVerb,
            },
            ["body"] = body,
        };
        return JsonSerializer.Serialize(card);
    }

    private static Dictionary<string, object> Header(string membership)
    {
        var columns = new List<object>
        {
            Column("stretch", Text("Cursor", weight: "Bolder", size: "Small")),
        };
        if (!string.IsNullOrEmpty(membership))
        {
            columns.Add(Column("auto", Text(membership, subtle: true, size: "Small")));
        }

        return new Dictionary<string, object>
        {
            ["type"] = "ColumnSet",
            ["spacing"] = "None",
            ["columns"] = columns,
        };
    }

    private static Dictionary<string, object> Row(string label, string value)
    {
        return new Dictionary<string, object>
        {
            ["type"] = "ColumnSet",
            ["spacing"] = "Small",
            ["columns"] = new object[]
            {
                Column("stretch", Text(label, subtle: true, size: "Small")),
                Column("auto", Text(value, weight: "Bolder", size: "Small")),
            },
        };
    }

    private static Dictionary<string, object> Bar(double fraction, bool warning, string normalStyle)
    {
        var fill = Formatting.RoundHalfAway(Math.Clamp(fraction, 0, 1) * 100);
        fill = Math.Clamp(fill, 0, 100);
        var rest = 100 - fill;
        var columns = new List<object>();
        if (fill > 0)
        {
            columns.Add(BarColumn(fill, warning ? "attention" : normalStyle));
        }

        if (rest > 0)
        {
            columns.Add(new Dictionary<string, object>
            {
                ["type"] = "Column",
                ["width"] = rest.ToString(System.Globalization.CultureInfo.InvariantCulture),
                ["items"] = Array.Empty<object>(),
            });
        }

        return new Dictionary<string, object>
        {
            ["type"] = "Container",
            ["style"] = "emphasis",
            ["spacing"] = "None",
            ["minHeight"] = "4px",
            ["items"] = new object[]
            {
                new Dictionary<string, object>
                {
                    ["type"] = "ColumnSet",
                    ["spacing"] = "None",
                    ["columns"] = columns,
                },
            },
        };
    }

    private static Dictionary<string, object> BarColumn(int width, string style)
    {
        return new Dictionary<string, object>
        {
            ["type"] = "Column",
            ["width"] = width.ToString(System.Globalization.CultureInfo.InvariantCulture),
            ["items"] = new object[]
            {
                new Dictionary<string, object>
                {
                    ["type"] = "Container",
                    ["style"] = style,
                    ["minHeight"] = "4px",
                    ["items"] = Array.Empty<object>(),
                },
            },
        };
    }

    private static Dictionary<string, object> Column(string width, Dictionary<string, object> item)
    {
        return new Dictionary<string, object>
        {
            ["type"] = "Column",
            ["width"] = width,
            ["items"] = new object[] { item },
        };
    }

    private static Dictionary<string, object> Text(
        string text,
        bool subtle = false,
        string size = "Default",
        string? weight = null,
        bool wrap = false)
    {
        var block = new Dictionary<string, object>
        {
            ["type"] = "TextBlock",
            ["text"] = text,
            ["wrap"] = wrap,
            ["spacing"] = "None",
        };
        if (subtle)
        {
            block["isSubtle"] = true;
        }

        if (size != "Default")
        {
            block["size"] = size;
        }

        if (weight is not null)
        {
            block["weight"] = weight;
        }

        return block;
    }
}
