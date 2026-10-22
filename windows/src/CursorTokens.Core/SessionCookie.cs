using System.Text.Json;

namespace CursorTokens;

public static class SessionCookie
{
    public static string JwtSubject(string token)
    {
        var parts = token.Split('.');
        if (parts.Length < 2)
        {
            throw new FormatException("malformed token");
        }

        var payload = parts[1].Replace('-', '+').Replace('_', '/');
        payload = payload.PadRight(payload.Length + (4 - payload.Length % 4) % 4, '=');
        byte[] bytes;
        try
        {
            bytes = Convert.FromBase64String(payload);
        }
        catch (FormatException exception)
        {
            throw new FormatException("malformed token", exception);
        }

        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(bytes);
        }
        catch (JsonException exception)
        {
            throw new FormatException("malformed token", exception);
        }

        using (document)
        {
            if (document.RootElement.ValueKind != JsonValueKind.Object
                || !document.RootElement.TryGetProperty("sub", out var subject)
                || subject.ValueKind != JsonValueKind.String
                || string.IsNullOrEmpty(subject.GetString()))
            {
                throw new FormatException("missing subject");
            }

            return subject.GetString()!;
        }
    }

    public static string Normalize(string value)
    {
        var trimmed = value.Trim();
        const string prefix = "WorkosCursorSessionToken=";
        if (trimmed.StartsWith(prefix, StringComparison.Ordinal))
        {
            trimmed = trimmed[prefix.Length..];
        }

        var decoded = DecodeFully(trimmed);
        if (decoded.Contains("::", StringComparison.Ordinal))
        {
            return decoded;
        }

        try
        {
            var subject = JwtSubject(decoded);
            return $"{subject}::{decoded}";
        }
        catch (FormatException)
        {
            return decoded;
        }
    }

    public static string HeaderValue(string stored)
    {
        var encoded = Uri.EscapeDataString(Normalize(stored));
        return $"WorkosCursorSessionToken={encoded}";
    }

    private static string DecodeFully(string value)
    {
        var current = value;
        for (var attempt = 0; attempt < 2; attempt++)
        {
            string decoded;
            try
            {
                decoded = Uri.UnescapeDataString(current);
            }
            catch (UriFormatException)
            {
                break;
            }

            if (decoded == current)
            {
                break;
            }

            current = decoded;
        }

        return current;
    }
}
