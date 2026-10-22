using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace CursorTokens;

public sealed class UnauthorizedException : Exception;

public sealed class ApiException : Exception
{
    public ApiException(string message)
        : base(message)
    {
    }

    public ApiException(string message, Exception inner)
        : base(message, inner)
    {
    }
}

public sealed class Summary
{
    public Summary(
        string? membership,
        double? cursorPercent,
        double? otherPercent,
        bool? onDemandEnabled,
        int? onDemandUsedCents,
        int? onDemandLimitCents)
    {
        Membership = membership;
        CursorPercent = cursorPercent;
        OtherPercent = otherPercent;
        OnDemandEnabled = onDemandEnabled;
        OnDemandUsedCents = onDemandUsedCents;
        OnDemandLimitCents = onDemandLimitCents;
    }

    public string? Membership { get; }

    public double? CursorPercent { get; }

    public double? OtherPercent { get; }

    public bool? OnDemandEnabled { get; }

    public int? OnDemandUsedCents { get; }

    public int? OnDemandLimitCents { get; }
}

public interface ICursorClient
{
    Task<Summary> FetchSummaryAsync(CancellationToken cancellationToken);

    Task<string?> FetchEmailAsync(CancellationToken cancellationToken);

    Task<int> FetchTotalTokensAsync(DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken);
}

public static class UsageApi
{
    public const string SummaryUrl = "https://cursor.com/api/usage-summary";

    public const string ProfileUrl = "https://cursor.com/api/auth/me";

    public const string AggregatedUrl = "https://cursor.com/api/dashboard/get-aggregated-usage-events";

    public static Summary ParseSummary(JsonElement payload)
    {
        var membership = payload.TryGetProperty("membershipType", out var membershipElement)
            && membershipElement.ValueKind == JsonValueKind.String
            ? membershipElement.GetString()
            : null;
        var plan = default(JsonElement);
        var onDemand = default(JsonElement);
        var hasOnDemand = false;
        if (payload.TryGetProperty("individualUsage", out var individual) && individual.ValueKind == JsonValueKind.Object)
        {
            if (individual.TryGetProperty("plan", out var planElement) && planElement.ValueKind == JsonValueKind.Object)
            {
                plan = planElement;
            }

            if (individual.TryGetProperty("onDemand", out var onDemandElement) && onDemandElement.ValueKind == JsonValueKind.Object)
            {
                onDemand = onDemandElement;
                hasOnDemand = true;
            }
        }

        bool? enabled = null;
        int? used = null;
        int? limit = null;
        if (hasOnDemand)
        {
            if (onDemand.TryGetProperty("enabled", out var enabledElement)
                && enabledElement.ValueKind is JsonValueKind.True or JsonValueKind.False)
            {
                enabled = enabledElement.GetBoolean();
            }

            used = NullableInt(onDemand, "used");
            limit = NullableInt(onDemand, "limit");
        }

        return new Summary(
            membership,
            PresentFloat(plan, "autoPercentUsed"),
            PresentFloat(plan, "apiPercentUsed"),
            enabled,
            used,
            limit);
    }

    public static int ParseTotalTokens(JsonElement payload)
    {
        var keys = new[]
        {
            "totalInputTokens",
            "totalOutputTokens",
            "totalCacheWriteTokens",
            "totalCacheReadTokens",
        };
        var parts = keys.Select(key => TokenPiece(payload, key)).ToArray();
        if (parts.Any(part => part is not null))
        {
            return parts.Sum(part => part ?? 0);
        }

        var total = 0;
        if (payload.TryGetProperty("aggregations", out var rows) && rows.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in rows.EnumerateArray())
            {
                if (row.ValueKind != JsonValueKind.Object)
                {
                    continue;
                }

                foreach (var key in new[] { "inputTokens", "outputTokens", "cacheWriteTokens", "cacheReadTokens" })
                {
                    total += TokenPiece(row, key) ?? 0;
                }
            }
        }

        return total;
    }

    public static string? ParseEmail(JsonElement payload)
    {
        if (payload.TryGetProperty("email", out var email)
            && email.ValueKind == JsonValueKind.String
            && !string.IsNullOrEmpty(email.GetString()))
        {
            return email.GetString();
        }

        return null;
    }

    private static double? PresentFloat(JsonElement obj, string key)
    {
        if (obj.ValueKind != JsonValueKind.Object || !obj.TryGetProperty(key, out var value))
        {
            return null;
        }

        if (value.ValueKind == JsonValueKind.Null)
        {
            return 0;
        }

        return FlexFloat(value) ?? throw new ApiException($"bad number for {key}");
    }

    private static int? NullableInt(JsonElement obj, string key)
    {
        if (obj.ValueKind != JsonValueKind.Object || !obj.TryGetProperty(key, out var value) || value.ValueKind == JsonValueKind.Null)
        {
            return null;
        }

        var parsed = FlexFloat(value) ?? throw new ApiException($"bad number for {key}");
        return Formatting.RoundHalfAway(parsed);
    }

    private static int? TokenPiece(JsonElement obj, string key)
    {
        if (obj.ValueKind != JsonValueKind.Object || !obj.TryGetProperty(key, out var value))
        {
            return null;
        }

        if (value.ValueKind == JsonValueKind.Null)
        {
            return 0;
        }

        var parsed = FlexFloat(value) ?? throw new ApiException($"bad token count for {key}");
        return Formatting.RoundHalfAway(parsed);
    }

    private static double? FlexFloat(JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Number)
        {
            return value.GetDouble();
        }

        if (value.ValueKind == JsonValueKind.String
            && double.TryParse(value.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed))
        {
            return parsed;
        }

        return null;
    }
}

public sealed class CursorClient : ICursorClient, IDisposable
{
    private const string UserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36";

    private readonly string _session;
    private readonly HttpClient _http;

    public CursorClient(string session, HttpMessageHandler? handler = null)
    {
        _session = session;
        _http = handler is null
            ? new HttpClient(new SocketsHttpHandler()) { Timeout = TimeSpan.FromSeconds(30) }
            : new HttpClient(handler, disposeHandler: false) { Timeout = TimeSpan.FromSeconds(30) };
    }

    public async Task<Summary> FetchSummaryAsync(CancellationToken cancellationToken)
    {
        using var document = await SendAsync(HttpMethod.Get, UsageApi.SummaryUrl, null, cancellationToken).ConfigureAwait(false);
        return UsageApi.ParseSummary(document.RootElement);
    }

    public async Task<string?> FetchEmailAsync(CancellationToken cancellationToken)
    {
        using var document = await SendAsync(HttpMethod.Get, UsageApi.ProfileUrl, null, cancellationToken).ConfigureAwait(false);
        return UsageApi.ParseEmail(document.RootElement);
    }

    public async Task<int> FetchTotalTokensAsync(DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken)
    {
        var body = new Dictionary<string, long>
        {
            ["teamId"] = -1,
            ["startDate"] = start.ToUnixTimeMilliseconds(),
            ["endDate"] = end.ToUnixTimeMilliseconds(),
        };
        using var document = await SendAsync(HttpMethod.Post, UsageApi.AggregatedUrl, body, cancellationToken).ConfigureAwait(false);
        return UsageApi.ParseTotalTokens(document.RootElement);
    }

    public void Dispose()
    {
        _http.Dispose();
    }

    private async Task<JsonDocument> SendAsync(
        HttpMethod method,
        string url,
        Dictionary<string, long>? body,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(method, url);
        request.Headers.TryAddWithoutValidation("Cookie", SessionCookie.HeaderValue(_session));
        request.Headers.TryAddWithoutValidation("Origin", "https://cursor.com");
        request.Headers.TryAddWithoutValidation("Referer", "https://cursor.com/dashboard?tab=usage");
        request.Headers.TryAddWithoutValidation("Accept", "application/json");
        request.Headers.TryAddWithoutValidation("User-Agent", UserAgent);
        if (body is not null)
        {
            var json = JsonSerializer.Serialize(body);
            request.Content = new StringContent(json, Encoding.UTF8);
            request.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
        }

        HttpResponseMessage response;
        try
        {
            response = await _http.SendAsync(request, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException)
        {
            throw new ApiException("Couldn't reach Cursor.");
        }

        using (response)
        {
            if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
            {
                throw new UnauthorizedException();
            }

            if (!response.IsSuccessStatusCode)
            {
                throw new ApiException($"HTTP {(int)response.StatusCode}");
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
                if (document.RootElement.ValueKind != JsonValueKind.Object)
                {
                    document.Dispose();
                    throw new ApiException("bad response");
                }

                return document;
            }
            catch (JsonException exception)
            {
                throw new ApiException("bad response", exception);
            }
        }
    }
}
