using System.Runtime.InteropServices;
using Microsoft.Windows.Widgets.Providers;
using WinRT;

namespace CursorTokens.Com;

internal static class NativeMethods
{
    [DllImport("ole32.dll")]
    internal static extern int CoRegisterClassObject(
        [MarshalAs(UnmanagedType.LPStruct)] Guid rclsid,
        [MarshalAs(UnmanagedType.IUnknown)] object pUnk,
        uint dwClsContext,
        uint flags,
        out uint lpdwRegister);

    [DllImport("ole32.dll")]
    internal static extern int CoRevokeClassObject(uint dwRegister);
}

internal static class ClassObject
{
    public static void Register(Guid clsid, object factory, out uint cookie)
    {
        var result = NativeMethods.CoRegisterClassObject(clsid, factory, 0x4, 0x1, out cookie);
        if (result != 0)
        {
            Marshal.ThrowExceptionForHR(result);
        }
    }

    public static void Revoke(uint cookie)
    {
        _ = NativeMethods.CoRevokeClassObject(cookie);
    }
}

[ComImport]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
[Guid("00000001-0000-0000-C000-000000000046")]
internal interface IClassFactory
{
    [PreserveSig]
    int CreateInstance(IntPtr outer, ref Guid iid, out IntPtr instance);

    [PreserveSig]
    int LockServer(bool lockServer);
}

internal sealed class WidgetProviderFactory<T> : IClassFactory
    where T : IWidgetProvider, new()
{
    private static readonly Guid IUnknown = new("00000000-0000-0000-C000-000000000046");
    private const int ClassENoAggregation = -2147221232;

    public int CreateInstance(IntPtr outer, ref Guid iid, out IntPtr instance)
    {
        instance = IntPtr.Zero;
        if (outer != IntPtr.Zero)
        {
            return ClassENoAggregation;
        }

        var created = MarshalInspectable<IWidgetProvider>.FromManaged(new T());
        if (iid == typeof(T).GUID || iid == IUnknown)
        {
            instance = created;
            return 0;
        }

        var result = Marshal.QueryInterface(created, ref iid, out instance);
        Marshal.Release(created);
        return result;
    }

    public int LockServer(bool lockServer)
    {
        return 0;
    }
}

internal sealed class RegistrationManager<T> : IDisposable
    where T : IWidgetProvider, new()
{
    private uint _cookie;
    private bool _disposed;

    private RegistrationManager(uint cookie)
    {
        _cookie = cookie;
    }

    public static RegistrationManager<T> Register()
    {
        ClassObject.Register(typeof(T).GUID, new WidgetProviderFactory<T>(), out var cookie);
        return new RegistrationManager<T>(cookie);
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        ClassObject.Revoke(_cookie);
    }
}
