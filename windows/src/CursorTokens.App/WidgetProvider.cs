using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Windows.Widgets.Providers;

namespace CursorTokens;

[ComVisible(true)]
[ComDefaultInterface(typeof(IWidgetProvider))]
[Guid(ClassId)]
public sealed class WidgetProvider : IWidgetProvider
{
    internal const string ClassId = "61e6d977-00ad-424f-9889-fe00b95510bb";

    private static readonly object Gate = new();
    private static readonly Dictionary<string, WidgetInstance> Instances = new();
    private static readonly ManualResetEvent EmptyList = new(false);
    private static Timer? RefreshTimer;
    private static int Refreshing;

    public WidgetProvider()
    {
        try
        {
            var infos = WidgetManager.GetDefault().GetWidgetInfos();
            if (infos is null)
            {
                return;
            }

            foreach (var info in infos)
            {
                var context = info.WidgetContext;
                lock (Gate)
                {
                    Instances.TryAdd(context.Id, new WidgetInstance(context.Id, context.DefinitionId));
                }
            }
        }
        catch (Exception error)
        {
            Debug.WriteLine(error.GetType().Name);
        }
    }

    public static void WaitUntilEmpty()
    {
        EmptyList.WaitOne();
    }

    public void CreateWidget(WidgetContext widgetContext)
    {
        var id = widgetContext.Id;
        var name = widgetContext.DefinitionId;
        lock (Gate)
        {
            Instances[id] = new WidgetInstance(id, name);
        }

        PushCached(id);
        RequestRefresh();
    }

    public void DeleteWidget(string widgetId, string customState)
    {
        _ = customState;
        var empty = false;
        lock (Gate)
        {
            Instances.Remove(widgetId);
            empty = Instances.Count == 0;
        }

        if (empty)
        {
            StopTimer();
            EmptyList.Set();
        }
    }

    public void OnActionInvoked(WidgetActionInvokedArgs actionInvokedArgs)
    {
        var id = actionInvokedArgs.WidgetContext.Id;
        if (!string.Equals(actionInvokedArgs.Verb, WidgetCard.StayVerb, StringComparison.Ordinal))
        {
            return;
        }

        PushCached(id);
        RequestRefresh();
    }

    public void OnWidgetContextChanged(WidgetContextChangedArgs contextChangedArgs)
    {
        PushCached(contextChangedArgs.WidgetContext.Id);
    }

    public void Activate(WidgetContext widgetContext)
    {
        var id = widgetContext.Id;
        lock (Gate)
        {
            if (!Instances.TryGetValue(id, out var instance))
            {
                instance = new WidgetInstance(id, widgetContext.DefinitionId);
                Instances[id] = instance;
            }

            instance.IsActive = true;
        }

        EnsureTimer();
        PushCached(id);
        RequestRefresh();
    }

    public void Deactivate(string widgetId)
    {
        var anyActive = false;
        lock (Gate)
        {
            if (Instances.TryGetValue(widgetId, out var instance))
            {
                instance.IsActive = false;
            }

            anyActive = Instances.Values.Any(instance => instance.IsActive);
        }

        if (!anyActive)
        {
            StopTimer();
        }
    }

    private static void EnsureTimer()
    {
        lock (Gate)
        {
            RefreshTimer ??= new Timer(_ => RequestRefresh(), null, RefreshSchedule.Interval, RefreshSchedule.Interval);
        }
    }

    private static void StopTimer()
    {
        lock (Gate)
        {
            RefreshTimer?.Dispose();
            RefreshTimer = null;
        }
    }

    private static void PushCached(string widgetId)
    {
        var snapshot = SnapshotStore.Load() ?? UsageSnapshot.SignedOut();
        Push(widgetId, WidgetCard.Build(snapshot));
    }

    private static void RequestRefresh()
    {
        _ = RefreshAsync();
    }

    private static async Task RefreshAsync()
    {
        if (Interlocked.Exchange(ref Refreshing, 1) == 1)
        {
            return;
        }

        try
        {
            var snapshot = await UsageRefresh.RefreshAsync().ConfigureAwait(false);
            var card = WidgetCard.Build(snapshot);
            List<string> ids;
            lock (Gate)
            {
                ids = Instances.Keys.ToList();
            }

            foreach (var id in ids)
            {
                Push(id, card);
            }
        }
        catch (Exception error)
        {
            Debug.WriteLine(error.GetType().Name);
        }
        finally
        {
            Interlocked.Exchange(ref Refreshing, 0);
        }
    }

    private static void Push(string widgetId, string template)
    {
        try
        {
            var options = new WidgetUpdateRequestOptions(widgetId);
            options.Template = template;
            options.Data = "{}";
            options.CustomState = "0";
            WidgetManager.GetDefault().UpdateWidget(options);
        }
        catch (Exception error)
        {
            Debug.WriteLine(error.GetType().Name);
        }
    }

    private sealed class WidgetInstance
    {
        public WidgetInstance(string id, string name)
        {
            Id = id;
            Name = name;
        }

        public string Id { get; }

        public string Name { get; }

        public bool IsActive { get; set; }
    }
}
