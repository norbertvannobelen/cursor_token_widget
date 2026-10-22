using Microsoft.Data.Sqlite;

namespace CursorTokens;

public sealed class LocalSessionException : Exception
{
    public LocalSessionException(string message)
        : base(message)
    {
    }

    public LocalSessionException(string message, Exception inner)
        : base(message, inner)
    {
    }
}

public static class LocalCursor
{
    public static string DatabasePath()
    {
        var roaming = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return Path.Combine(roaming, "Cursor", "User", "globalStorage", "state.vscdb");
    }

    public static string Load(string? databasePath = null)
    {
        var path = databasePath ?? DatabasePath();
        if (!File.Exists(path))
        {
            throw new LocalSessionException("Cursor doesn't look installed for this user.");
        }

        try
        {
            var builder = new SqliteConnectionStringBuilder
            {
                DataSource = path,
                Mode = SqliteOpenMode.ReadOnly,
                Pooling = false,
            };
            using var connection = new SqliteConnection(builder.ConnectionString);
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1";
            var value = command.ExecuteScalar() as string;
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new LocalSessionException("Cursor is installed, but no account is signed in.");
            }

            var token = value.Trim();
            string subject;
            try
            {
                subject = SessionCookie.JwtSubject(token);
            }
            catch (FormatException exception)
            {
                throw new LocalSessionException(
                    "The Cursor session on this computer couldn't be used. Paste a session token instead.",
                    exception);
            }

            return $"{subject}::{token}";
        }
        catch (LocalSessionException)
        {
            throw;
        }
        catch (Exception exception)
        {
            throw new LocalSessionException(
                "Couldn't read the Cursor session. Paste a session token instead.",
                exception);
        }
    }
}
