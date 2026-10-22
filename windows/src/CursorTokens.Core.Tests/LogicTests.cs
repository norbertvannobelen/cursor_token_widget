using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Xunit;

namespace CursorTokens.Tests;

[CollectionDefinition("store", DisableParallelization = true)]
public sealed class StoreCollection;

[Collection("store")]
public sealed class LogicTests
{
    [Fact]
    public void PercentRoundingMatchesDashboard()
    {
        Assert.Equal("41%", Formatting.FormatPercent(41.2075));
        Assert.Equal("83%", Formatting.FormatPercent(82.672727));
        Assert.Equal("42%", Formatting.FormatPercent(41.84));
        Assert.Equal(Formatting.EmDash, Formatting.FormatPercent(null));
    }

    [Fact]
    public void TokenCountsUseDashboardScale()
    {
        Assert.Equal("30.3M", Formatting.FormatTokenCount(30_284_186));
        Assert.Equal("909.2M", Formatting.FormatTokenCount(909_200_000));
        Assert.Equal("1.3B", Formatting.FormatTokenCount(1_279_903_814));
        Assert.Equal("1M", Formatting.FormatTokenCount(999_999));
        Assert.Equal("12", Formatting.FormatTokenCount(12));
        Assert.Equal(Formatting.EmDash, Formatting.FormatTokenCount(null));
    }

    [Fact]
    public void OnDemandCentsAndWarningThreshold()
    {
        Assert.Equal("$0", Formatting.FormatCents(0));
        Assert.Equal("$50", Formatting.FormatCents(5_000));
        Assert.Equal("$12.50", Formatting.FormatCents(1_250));
        Assert.Equal(Formatting.EmDash, Formatting.FormatCents(null));
        Assert.False(Formatting.ExceedsWarning(90));
        Assert.False(Formatting.ExceedsWarning(82.67));
        Assert.True(Formatting.ExceedsWarning(90.5));
        Assert.True(Formatting.ExceedsWarning(96));

        var demand = OnDemandDisplay.From(true, 0, 5_000);
        Assert.NotNull(demand);
        Assert.Equal("$0", demand.UsageText);
        Assert.Equal("$50", demand.LimitText);
        Assert.Equal("$0/$50", demand.PairText);
        Assert.Null(OnDemandDisplay.From(null, null, null));

        var unlimited = OnDemandDisplay.From(true, 1_250, null);
        Assert.NotNull(unlimited);
        Assert.Equal("No limit", unlimited.LimitText);
        Assert.Equal("$12.50", unlimited.PairText);
        Assert.False(unlimited.HasBar);
    }

    [Fact]
    public void BarFractionClamps()
    {
        Assert.Equal(0.5, Formatting.BarFraction(50));
        Assert.Equal(1, Formatting.BarFraction(140));
        Assert.Equal(0, Formatting.BarFraction(null));
    }

    [Fact]
    public void SevenDayWindowIncludesToday()
    {
        var now = DateTimeOffset.FromUnixTimeSeconds(1_761_148_800);
        var start = Formatting.WindowStart(6, now);
        var today = new DateTimeOffset(now.Year, now.Month, now.Day, 0, 0, 0, now.Offset);
        Assert.Equal(6, (today - start).TotalDays);
    }

    [Fact]
    public void MembershipLabels()
    {
        Assert.Equal("Pro+", Formatting.MembershipLabel("pro_plus"));
        Assert.Equal("Pro", Formatting.MembershipLabel("pro"));
        Assert.Equal("Ultra", Formatting.MembershipLabel("ultra"));
        Assert.Equal("Team", Formatting.MembershipLabel("enterprise"));
    }

    [Fact]
    public void CookieEncodesSubjectSeparator()
    {
        var header = SessionCookie.HeaderValue("google-oauth2|abc::aaa.bbb.ccc");
        Assert.StartsWith("WorkosCursorSessionToken=", header);
        Assert.Contains("%7C", header);
        Assert.Contains("%3A%3A", header);
        Assert.DoesNotContain("::", header);
    }

    [Fact]
    public void RawJwtGainsSubject()
    {
        var payload = Convert.ToBase64String(Encoding.UTF8.GetBytes("{\"sub\":\"google-oauth2|abc\"}"))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
        var token = $"eyJhbGciOiJIUzI1NiJ9.{payload}.sig";
        var stored = SessionCookie.Normalize(token);
        Assert.StartsWith("google-oauth2|abc::", stored);
        Assert.Equal("google-oauth2|abc", SessionCookie.JwtSubject(token));
    }

    [Fact]
    public void SummaryPercentsAndOnDemand()
    {
        using var document = JsonDocument.Parse(
            """
            {
              "membershipType": "pro_plus",
              "individualUsage": {
                "plan": {"autoPercentUsed": 41.2075, "apiPercentUsed": 82.67},
                "onDemand": {"enabled": true, "used": 0, "limit": 5000, "remaining": 5000}
              }
            }
            """);
        var summary = UsageApi.ParseSummary(document.RootElement);
        Assert.Equal("pro_plus", summary.Membership);
        Assert.Equal(41.2075, summary.CursorPercent);
        Assert.Equal(82.67, summary.OtherPercent);
        Assert.Equal(0, summary.OnDemandUsedCents);
        Assert.Equal(5000, summary.OnDemandLimitCents);

        using var unlimited = JsonDocument.Parse(
            """
            {"individualUsage": {"onDemand": {"enabled": true, "used": 1250, "limit": null}}}
            """);
        var parsed = UsageApi.ParseSummary(unlimited.RootElement);
        Assert.Equal(1250, parsed.OnDemandUsedCents);
        Assert.Null(parsed.OnDemandLimitCents);
    }

    [Fact]
    public void AggregatedTokens()
    {
        using var direct = JsonDocument.Parse(
            """
            {"totalInputTokens": "10", "totalOutputTokens": 2, "totalCacheReadTokens": "30", "aggregations": []}
            """);
        Assert.Equal(42, UsageApi.ParseTotalTokens(direct.RootElement));

        using var rows = JsonDocument.Parse(
            """
            {"aggregations": [{"inputTokens": "4", "outputTokens": "1", "cacheReadTokens": "5"}]}
            """);
        Assert.Equal(10, UsageApi.ParseTotalTokens(rows.RootElement));
    }

    [Fact]
    public void ReadsAccessToken()
    {
        var payload = Convert.ToBase64String(Encoding.UTF8.GetBytes("{\"sub\":\"google-oauth2|abc\"}"))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
        var token = $"header.{payload}.sig";
        var directory = Directory.CreateTempSubdirectory("cursor-tokens-db-");
        try
        {
            var database = Path.Combine(directory.FullName, "state.vscdb");
            using (var connection = new SqliteConnection($"Data Source={database}"))
            {
                connection.Open();
                using var command = connection.CreateCommand();
                command.CommandText = "CREATE TABLE ItemTable (key TEXT, value TEXT)";
                command.ExecuteNonQuery();
                command.CommandText = "INSERT INTO ItemTable (key, value) VALUES ('cursorAuth/accessToken', $token)";
                command.Parameters.AddWithValue("$token", token);
                command.ExecuteNonQuery();
            }

            SqliteConnection.ClearAllPools();
            Assert.Equal($"google-oauth2|abc::{token}", LocalCursor.Load(database));
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            directory.Delete(recursive: true);
        }
    }

    [Fact]
    public void MissingDatabase()
    {
        var error = Assert.Throws<LocalSessionException>(() => LocalCursor.Load(Path.Combine(Path.GetTempPath(), "cursor-tokens-missing-state.vscdb")));
        Assert.Equal("Cursor doesn't look installed for this user.", error.Message);
    }

    [Fact]
    public async Task RefreshWritesDisplaySnapshot()
    {
        var client = new FakeClient
        {
            Summary = new Summary("pro_plus", 44.2, 96.2, true, 0, 5_000),
            Email = "person@example.com",
            Tokens = 1_230,
        };
        var snapshot = await WithData(async () =>
        {
            SessionStore.Save("google-oauth2|abc::token");
            return await UsageRefresh.RefreshAsync(
                new DateTimeOffset(2026, 10, 22, 18, 0, 0, TimeSpan.Zero),
                _ => client);
        });

        Assert.True(snapshot.SignedIn);
        Assert.Equal("Pro+", snapshot.Membership);
        Assert.Equal("44%", snapshot.Cursor.Text);
        Assert.False(snapshot.Cursor.Warning);
        Assert.Equal("96%", snapshot.Other.Text);
        Assert.True(snapshot.Other.Warning);
        Assert.NotNull(snapshot.OnDemand);
        Assert.Equal("$0/$50", snapshot.OnDemand.PairText);
        Assert.Equal("1.2K", snapshot.Tokens.Today);
        Assert.Equal("person@example.com", snapshot.Email);

        var card = WidgetCard.Build(snapshot);
        using var document = JsonDocument.Parse(card);
        Assert.Equal("stay", document.RootElement.GetProperty("selectAction").GetProperty("verb").GetString());
        Assert.Equal("Action.Execute", document.RootElement.GetProperty("selectAction").GetProperty("type").GetString());
        Assert.DoesNotContain("Action.OpenUrl", card, StringComparison.Ordinal);
        Assert.DoesNotContain("person@example.com", card, StringComparison.Ordinal);
        Assert.Contains("$0/$50", card, StringComparison.Ordinal);
        var styles = new List<string>();
        CollectStyles(document.RootElement, styles);
        Assert.Contains("accent", styles);
        Assert.Contains("attention", styles);
    }

    [Fact]
    public async Task UnauthorizedClearsSession()
    {
        await WithData(async () =>
        {
            SessionStore.Save("google-oauth2|abc::token");
            var snapshot = await UsageRefresh.RefreshAsync(clientFactory: _ => new FakeClient { Unauthorized = true });
            Assert.False(snapshot.SignedIn);
            Assert.Equal("Session expired. Sign in again.", snapshot.Error);
            Assert.Null(SessionStore.Load());
        });
    }

    [Fact]
    public async Task NetworkFailureKeepsPreviousSnapshot()
    {
        await WithData(async () =>
        {
            SessionStore.Save("google-oauth2|abc::token");
            var previous = UsageSnapshot.Create(signedIn: true, cursorPercent: 10, otherPercent: 20, updatedAt: DateTimeOffset.UnixEpoch);
            SnapshotStore.Save(previous);
            var snapshot = await UsageRefresh.RefreshAsync(clientFactory: _ => new FakeClient { Fail = true });
            Assert.True(snapshot.SignedIn);
            Assert.Equal("10%", snapshot.Cursor.Text);
            Assert.Equal("Couldn't reach Cursor. Showing the last update.", snapshot.Error);
        });
    }

    [Fact]
    public async Task RequestsUseCookieOriginAndPostBody()
    {
        var calls = new List<CapturedCall>();
        var handler = new ScriptedHandler(request =>
        {
            calls.Add(CapturedCall.From(request));
            var json = request.RequestUri!.AbsolutePath.EndsWith("usage-summary", StringComparison.Ordinal)
                ? """{"individualUsage":{"plan":{"autoPercentUsed":1,"apiPercentUsed":2}}}"""
                : """{"totalInputTokens":1}""";
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json"),
            };
        });
        using var client = new CursorClient("google-oauth2|abc::aaa.bbb.ccc", handler);
        _ = await client.FetchSummaryAsync(CancellationToken.None);
        _ = await client.FetchTotalTokensAsync(DateTimeOffset.UnixEpoch, DateTimeOffset.UnixEpoch.AddHours(1), CancellationToken.None);

        Assert.Equal(2, calls.Count);
        Assert.Equal("https://cursor.com", calls[0].Origin);
        Assert.Contains("%7C", calls[0].Cookie, StringComparison.Ordinal);
        Assert.Contains("%3A%3A", calls[0].Cookie, StringComparison.Ordinal);
        Assert.DoesNotContain("::", calls[0].Cookie, StringComparison.Ordinal);
        Assert.Equal("POST", calls[1].Method);
        Assert.Contains("\"teamId\":-1", calls[1].Body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ForbiddenClearsThroughTheClient()
    {
        var handler = new ScriptedHandler(_ => new HttpResponseMessage(HttpStatusCode.Forbidden));
        using var client = new CursorClient("subject::token", handler);
        await Assert.ThrowsAsync<UnauthorizedException>(() => client.FetchSummaryAsync(CancellationToken.None));
    }

    [Fact]
    public void RefreshIntervalIsFiveMinutes()
    {
        Assert.Equal(TimeSpan.FromMinutes(5), RefreshSchedule.Interval);
    }

    [Fact]
    public void PackageManifestMatchesTheProvider()
    {
        var appDir = Path.Combine(RepoRoot(), "windows", "src", "CursorTokens.App");
        var manifest = File.ReadAllText(Path.Combine(appDir, "Package.appxmanifest"));
        var provider = File.ReadAllText(Path.Combine(appDir, "WidgetProvider.cs"));
        var program = File.ReadAllText(Path.Combine(appDir, "Program.cs"));
        const string classId = "61e6d977-00ad-424f-9889-fe00b95510bb";
        Assert.Contains(classId, manifest, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(classId, provider, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("-RegisterProcessAsComServer", manifest, StringComparison.Ordinal);
        Assert.Contains("-RegisterProcessAsComServer", program, StringComparison.Ordinal);
        Assert.Contains("internetClient", manifest, StringComparison.Ordinal);
        Assert.Contains("unvirtualizedResources", manifest, StringComparison.Ordinal);
        Assert.Contains("CursorUsage", manifest, StringComparison.Ordinal);
        Assert.Contains("Name=\"small\"", manifest, StringComparison.Ordinal);
        foreach (var relative in new[]
        {
            "Assets/StoreLogo.png",
            "Assets/Square44x44Logo.scale-200.png",
            "Assets/Square150x150Logo.scale-200.png",
            "Assets/Wide310x150Logo.scale-200.png",
            "Assets/SplashScreen.scale-200.png",
            "Assets/LockScreenLogo.scale-200.png",
            "Assets/Square44x44Logo.targetsize-24_altform-unplated.png",
            "ProviderAssets/CursorUsage_Icon.png",
            "ProviderAssets/CursorUsage_Screenshot.png",
        })
        {
            var path = Path.Combine(appDir, relative);
            var header = File.ReadAllBytes(path).AsSpan(0, 8);
            Assert.Equal(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }, header.ToArray());
        }
    }

    private static async Task<UsageSnapshot> WithData(Func<Task<UsageSnapshot>> body)
    {
        var previous = Environment.GetEnvironmentVariable("CURSOR_TOKENS_DATA_DIR");
        var directory = Directory.CreateTempSubdirectory("cursor-tokens-data-");
        Environment.SetEnvironmentVariable("CURSOR_TOKENS_DATA_DIR", directory.FullName);
        try
        {
            return await body();
        }
        finally
        {
            Environment.SetEnvironmentVariable("CURSOR_TOKENS_DATA_DIR", previous);
            directory.Delete(recursive: true);
        }
    }

    private static async Task WithData(Func<Task> body)
    {
        _ = await WithData(async () =>
        {
            await body();
            return UsageSnapshot.SignedOut();
        });
    }

    private static void CollectStyles(JsonElement element, List<string> styles)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in element.EnumerateObject())
            {
                if (property.NameEquals("style") && property.Value.ValueKind == JsonValueKind.String)
                {
                    var style = property.Value.GetString();
                    if (!string.IsNullOrEmpty(style))
                    {
                        styles.Add(style);
                    }
                }

                CollectStyles(property.Value, styles);
            }
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in element.EnumerateArray())
            {
                CollectStyles(item, styles);
            }
        }
    }

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, "windows", "src", "CursorTokens.App")))
            {
                return dir.FullName;
            }

            dir = dir.Parent;
        }

        throw new DirectoryNotFoundException("repo root");
    }

    private sealed class FakeClient : ICursorClient
    {
        public Summary Summary { get; init; } = new(null, null, null, null, null, null);

        public string? Email { get; init; }

        public int Tokens { get; init; }

        public bool Unauthorized { get; init; }

        public bool Fail { get; init; }

        public Task<Summary> FetchSummaryAsync(CancellationToken cancellationToken)
        {
            if (Unauthorized)
            {
                throw new UnauthorizedException();
            }

            if (Fail)
            {
                throw new ApiException("down");
            }

            return Task.FromResult(Summary);
        }

        public Task<string?> FetchEmailAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(Email);
        }

        public Task<int> FetchTotalTokensAsync(DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken)
        {
            return Task.FromResult(Tokens);
        }
    }

    private sealed class CapturedCall
    {
        public string Method { get; init; } = "";

        public string Origin { get; init; } = "";

        public string Cookie { get; init; } = "";

        public string Body { get; init; } = "";

        public static CapturedCall From(HttpRequestMessage request)
        {
            return new CapturedCall
            {
                Method = request.Method.Method,
                Origin = request.Headers.TryGetValues("Origin", out var origin) ? origin.Single() : "",
                Cookie = request.Headers.TryGetValues("Cookie", out var cookie) ? cookie.Single() : "",
                Body = request.Content is null ? "" : request.Content.ReadAsStringAsync().GetAwaiter().GetResult(),
            };
        }
    }

    private sealed class ScriptedHandler : HttpMessageHandler
    {
        private readonly Func<HttpRequestMessage, HttpResponseMessage> _respond;

        public ScriptedHandler(Func<HttpRequestMessage, HttpResponseMessage> respond)
        {
            _respond = respond;
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(_respond(request));
        }
    }
}
