using System.Text.Json;

namespace CursorTokens;

public static class AppPaths
{
    public static string DataDirectory()
    {
        var overrideDir = Environment.GetEnvironmentVariable("CURSOR_TOKENS_DATA_DIR");
        string path;
        if (!string.IsNullOrWhiteSpace(overrideDir))
        {
            path = overrideDir;
        }
        else
        {
            var root = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            path = Path.Combine(root, "Cursor Tokens");
        }

        Directory.CreateDirectory(path);
        return path;
    }

    public static string SessionFile()
    {
        return Path.Combine(DataDirectory(), "session");
    }

    public static string SnapshotFile()
    {
        return Path.Combine(DataDirectory(), "snapshot.json");
    }
}

public static class SessionStore
{
    public static string? Load()
    {
        var path = AppPaths.SessionFile();
        if (!File.Exists(path))
        {
            return null;
        }

        var text = File.ReadAllText(path).Trim();
        return text.Length == 0 ? null : text;
    }

    public static void Save(string value)
    {
        WritePrivate(AppPaths.SessionFile(), value.Trim() + "\n");
    }

    public static void Delete()
    {
        var path = AppPaths.SessionFile();
        if (File.Exists(path))
        {
            File.Delete(path);
        }
    }

    internal static void WritePrivate(string path, string text)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + ".tmp";
        File.WriteAllText(temporary, text);
        Restrict(temporary);
        File.Move(temporary, path, overwrite: true);
        Restrict(path);
    }

    private static void Restrict(string path)
    {
        if (OperatingSystem.IsWindows())
        {
            return;
        }

        File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.UserWrite);
    }
}

public static class SnapshotStore
{
    public static UsageSnapshot? Load()
    {
        var path = AppPaths.SnapshotFile();
        if (!File.Exists(path))
        {
            return null;
        }

        try
        {
            var payload = File.ReadAllText(path);
            return JsonSerializer.Deserialize<UsageSnapshot>(payload, SnapshotJson.Options);
        }
        catch (Exception error) when (error is IOException or JsonException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    public static void Save(UsageSnapshot snapshot)
    {
        var json = JsonSerializer.Serialize(snapshot, SnapshotJson.Options) + "\n";
        SessionStore.WritePrivate(AppPaths.SnapshotFile(), json);
    }
}
