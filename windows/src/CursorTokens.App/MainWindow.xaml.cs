using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace CursorTokens;

public sealed partial class MainWindow : Window
{
    private static readonly SolidColorBrush Accent = new(Color.FromArgb(255, 0, 120, 212));
    private static readonly SolidColorBrush Muted = new(Color.FromArgb(255, 138, 143, 152));
    private static readonly SolidColorBrush Spend = new(Color.FromArgb(255, 16, 124, 16));
    private static readonly SolidColorBrush Critical = new(Color.FromArgb(255, 196, 43, 28));

    private readonly DispatcherTimer _timer;
    private int _refreshing;

    public MainWindow()
    {
        InitializeComponent();
        AppWindow.Resize(new Windows.Graphics.SizeInt32(440, 720));
        _timer = new DispatcherTimer { Interval = RefreshSchedule.Interval };
        _timer.Tick += async (_, _) => await RefreshAsync();
        _timer.Start();
        Closed += (_, _) => _timer.Stop();
        var existing = SnapshotStore.Load();
        if (existing is { SignedIn: true })
        {
            Apply(existing);
        }

        _ = RefreshAsync();
    }

    private async void LocalButton_Click(object sender, RoutedEventArgs e)
    {
        await RunSignIn(() => SignIn.WithLocalCursor());
    }

    private async void BrowserButton_Click(object sender, RoutedEventArgs e)
    {
        _ = await Windows.System.Launcher.LaunchUriAsync(new Uri("https://cursor.com/dashboard"));
    }

    private async void PasteButton_Click(object sender, RoutedEventArgs e)
    {
        var token = TokenBox.Password;
        TokenBox.Password = "";
        await RunSignIn(() => SignIn.WithToken(token));
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        await RefreshAsync();
    }

    private void SignOutButton_Click(object sender, RoutedEventArgs e)
    {
        SignIn.Out();
        Apply(UsageSnapshot.SignedOut());
    }

    private async Task RunSignIn(Action action)
    {
        try
        {
            await Task.Run(action);
            SignInError.Text = "";
            await RefreshAsync();
        }
        catch (LocalSessionException error)
        {
            SignInError.Text = error.Message;
        }
        catch (Exception)
        {
            SignInError.Text = "Couldn't save the session.";
        }
    }

    private async Task RefreshAsync()
    {
        if (Interlocked.Exchange(ref _refreshing, 1) == 1)
        {
            return;
        }

        try
        {
            var snapshot = await UsageRefresh.RefreshAsync();
            DispatcherQueue.TryEnqueue(() => Apply(snapshot));
        }
        catch (Exception)
        {
            DispatcherQueue.TryEnqueue(() =>
            {
                ErrorText.Text = "Couldn't reach Cursor. Showing the last update.";
            });
        }
        finally
        {
            Interlocked.Exchange(ref _refreshing, 0);
        }
    }

    private void Apply(UsageSnapshot snapshot)
    {
        if (!snapshot.SignedIn)
        {
            SignedInView.Visibility = Visibility.Collapsed;
            SignedOutView.Visibility = Visibility.Visible;
            SignInError.Text = snapshot.Error ?? "";
            return;
        }

        SignedOutView.Visibility = Visibility.Collapsed;
        SignedInView.Visibility = Visibility.Visible;
        MembershipText.Text = snapshot.Membership;
        EmailText.Text = snapshot.Email;
        CursorPercent.Text = snapshot.Cursor.Text;
        OtherPercent.Text = snapshot.Other.Text;
        Paint(CursorBar, snapshot.Cursor, Accent);
        Paint(OtherBar, snapshot.Other, Muted);
        if (snapshot.OnDemand is { } demand)
        {
            OnDemandPanel.Visibility = Visibility.Visible;
            OnDemandUsage.Text = demand.UsageText;
            OnDemandLimit.Text = demand.LimitText;
            OnDemandBar.Visibility = demand.HasBar ? Visibility.Visible : Visibility.Collapsed;
            OnDemandBar.Value = demand.Fraction * 100;
            OnDemandBar.Foreground = demand.Warning ? Critical : Spend;
        }
        else
        {
            OnDemandPanel.Visibility = Visibility.Collapsed;
        }

        TodayText.Text = snapshot.Tokens.Today;
        WeekText.Text = snapshot.Tokens.Week;
        MonthText.Text = snapshot.Tokens.Month;
        UpdatedText.Text = string.IsNullOrEmpty(snapshot.UpdatedText) ? "" : "Updated " + snapshot.UpdatedText;
        ErrorText.Text = snapshot.Error ?? "";
    }

    private static void Paint(ProgressBar bar, Meter meter, SolidColorBrush normal)
    {
        bar.Value = meter.Fraction * 100;
        bar.Foreground = meter.Warning ? Critical : normal;
    }
}
