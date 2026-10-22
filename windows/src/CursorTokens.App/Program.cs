using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;

namespace CursorTokens;

public static class Program
{
    [System.Runtime.InteropServices.DllImport("kernel32.dll")]
    private static extern IntPtr GetConsoleWindow();

    public static void Main(string[] args)
    {
        if (args.Length > 0 && string.Equals(args[0], "-RegisterProcessAsComServer", StringComparison.Ordinal))
        {
            RunWidgetServer();
            return;
        }

        var ui = new Thread(StartWindow);
        ui.SetApartmentState(ApartmentState.STA);
        ui.Start();
        ui.Join();
    }

    private static void RunWidgetServer()
    {
        WinRT.ComWrappersSupport.InitializeComWrappers();
        using var registration = Com.RegistrationManager<WidgetProvider>.Register();
        if (GetConsoleWindow() != IntPtr.Zero)
        {
            Console.ReadLine();
            return;
        }

        WidgetProvider.WaitUntilEmpty();
    }

    private static void StartWindow()
    {
        WinRT.ComWrappersSupport.InitializeComWrappers();
        Application.Start(_ =>
        {
            var context = new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread());
            SynchronizationContext.SetSynchronizationContext(context);
            new App();
        });
    }
}
