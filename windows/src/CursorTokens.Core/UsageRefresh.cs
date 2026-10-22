namespace CursorTokens;

public static class RefreshSchedule
{
    public static readonly TimeSpan Interval = TimeSpan.FromMinutes(5);
}

public static class SignIn
{
    public static void WithToken(string raw)
    {
        var stored = SessionCookie.Normalize(raw);
        if (!stored.Contains("::", StringComparison.Ordinal))
        {
            throw new LocalSessionException("Paste the WorkosCursorSessionToken value.");
        }

        SessionStore.Save(stored);
    }

    public static void WithLocalCursor(string? databasePath = null)
    {
        SessionStore.Save(LocalCursor.Load(databasePath));
    }

    public static void Out(DateTimeOffset? now = null)
    {
        SessionStore.Delete();
        SnapshotStore.Save(UsageSnapshot.SignedOut(now));
    }
}

public static class UsageRefresh
{
    public static async Task<UsageSnapshot> RefreshAsync(
        DateTimeOffset? now = null,
        Func<string, ICursorClient>? clientFactory = null,
        CancellationToken cancellationToken = default)
    {
        var moment = now ?? DateTimeOffset.Now;
        var session = SessionStore.Load();
        if (string.IsNullOrEmpty(session))
        {
            var signedOut = UsageSnapshot.SignedOut(moment);
            SnapshotStore.Save(signedOut);
            return signedOut;
        }

        var client = (clientFactory ?? (value => new CursorClient(value))).Invoke(session);
        using var lifetime = client as IDisposable;
        try
        {
            var summary = await client.FetchSummaryAsync(cancellationToken).ConfigureAwait(false);
            var todayStart = Formatting.WindowStart(0, moment);
            var weekStart = Formatting.WindowStart(6, moment);
            var monthStart = Formatting.WindowStart(29, moment);
            var todayTask = Tokens(client, todayStart, moment, cancellationToken);
            var weekTask = Tokens(client, weekStart, moment, cancellationToken);
            var monthTask = Tokens(client, monthStart, moment, cancellationToken);
            var emailTask = Email(client, cancellationToken);
            await Task.WhenAll(todayTask, weekTask, monthTask, emailTask).ConfigureAwait(false);
            var snapshot = UsageSnapshot.Create(
                signedIn: true,
                cursorPercent: summary.CursorPercent,
                otherPercent: summary.OtherPercent,
                todayTokens: await todayTask.ConfigureAwait(false),
                weekTokens: await weekTask.ConfigureAwait(false),
                monthTokens: await monthTask.ConfigureAwait(false),
                onDemandEnabled: summary.OnDemandEnabled,
                onDemandUsedCents: summary.OnDemandUsedCents,
                onDemandLimitCents: summary.OnDemandLimitCents,
                membership: summary.Membership,
                email: await emailTask.ConfigureAwait(false),
                updatedAt: moment);
            SnapshotStore.Save(snapshot);
            return snapshot;
        }
        catch (UnauthorizedException)
        {
            SessionStore.Delete();
            var snapshot = UsageSnapshot.SignedOut(moment, "Session expired. Sign in again.");
            SnapshotStore.Save(snapshot);
            return snapshot;
        }
        catch (ApiException)
        {
            var previous = SnapshotStore.Load();
            var snapshot = previous is { SignedIn: true } ? previous : UsageSnapshot.SignedOut(moment);
            snapshot.Error = "Couldn't reach Cursor. Showing the last update.";
            SnapshotStore.Save(snapshot);
            return snapshot;
        }
    }

    private static async Task<long?> Tokens(
        ICursorClient client,
        DateTimeOffset start,
        DateTimeOffset end,
        CancellationToken cancellationToken)
    {
        try
        {
            return await client.FetchTotalTokensAsync(start, end, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception error) when (error is ApiException or UnauthorizedException)
        {
            return null;
        }
    }

    private static async Task<string?> Email(ICursorClient client, CancellationToken cancellationToken)
    {
        try
        {
            return await client.FetchEmailAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (Exception error) when (error is ApiException or UnauthorizedException)
        {
            return null;
        }
    }
}
