# Cursor Tokens

A small macOS app and desktop widget for the same Cursor usage figures as the dashboard.

- **Cursor Models** and **Other Models** allowance, as a percent and a bar
- **Today**, **7 days**, and **30 days** token totals
- The desktop widget refreshes about every 5 minutes on its own, including while Cursor Tokens is quit. The app window uses the same interval while it is open.

The widget is the small system size, the same class as the small Weather widget.

## Sign in

Open **Cursor Tokens** and use one of these:

1. **Use the account signed in to Cursor** reads the session already stored by the Cursor app on this Mac. From Terminal, `open -a "Cursor Tokens" --args --use-local-cursor` does the same thing.
2. **Sign in with email or SSO** opens Cursor’s site inside the app and keeps the session cookie.
3. **Paste a session token** if a provider blocks the embedded browser. In Safari, open [cursor.com/dashboard](https://cursor.com/dashboard), then copy the `WorkosCursorSessionToken` cookie value.

The session is shared with the widget, which uses it for its own refresh. It is not written into this repo.

## Build

Requires Xcode 16 or later, signed in to the Apple team `2CSRPDZQ8D`. The first build registers this Mac and creates the App Group used by the widget.

```bash
make build
make test
make install
```

`make install` copies `Cursor Tokens.app` to `/Applications` and launches it. Launch the app once so macOS registers the widget.

## Add the widget

Control-click the desktop, choose **Edit Widgets**, search for **Cursor Usage**, and drag the small widget onto the desktop.

With Cursor Tokens in front, open the **Cursor Tokens** menu in the menu bar. **Add Desktop Widget…** shows how to place the widget. **Show Menu Bar Icon** adds an icon in the menu bar. Click that icon for the same allowance, on-demand, and token details as the widget. Choose the menu item again to remove the icon. The icon stays after you close the window, and macOS can open it again at login.

## Refresh

The widget asks macOS for a new timeline every 5 minutes and loads the usage itself, using the shared session. That continues after you quit Cursor Tokens. While the app is open it refreshes on the same interval and asks the widget to reload. macOS can delay a scheduled widget refresh while the Mac is idle.

## Linux (KDE Plasma 6)

The same figures are available as a Plasma widget and a Kirigami window. A bar turns red once its displayed usage is over 90%, including on-demand spend against its limit. Clicking the widget does not open the window.

Requirements: Python 3, and Plasma 6 (`kpackagetool6`). The window also needs Qt 6 and Kirigami 6 to compile. Sign-in is the Cursor account already stored by the editor, or a pasted `WorkosCursorSessionToken`. There is no embedded browser; the sign-in page can open cursor.com so the cookie can be copied.

```bash
make -C linux test
make -C linux install
```

That installs `cursor-tokens` on `~/.local/bin`, registers the **Cursor Usage** widget for the current user, and builds **Cursor Tokens** when the Qt packages are present. Add the widget from the desktop: right-click the wallpaper, choose **Add Widgets**, and search for **Cursor Usage**. Sign in from the widget’s **Configure Cursor Usage** action, or from the Cursor Tokens application.

The widget and the window both call `cursor-tokens refresh` every 5 minutes. The session file stays in `$XDG_DATA_HOME/cursor-tokens` (mode 0600) and is not written into this repo.

## Windows 11

The same figures are a Widgets Board widget plus a window. A bar turns red once its displayed usage is over 90%, including on-demand spend against its limit. A click on the widget refreshes the numbers in place.

Requirements: Windows 11, Developer Mode, Visual Studio 2022 or later with the Windows application development workload, and the .NET 8 SDK. The package uses Windows App SDK 2.3.1. Sign-in is the Cursor account already stored by the editor (`%APPDATA%\Cursor\User\globalStorage\state.vscdb`), or a pasted `WorkosCursorSessionToken`. The sign-in page opens in the browser so the cookie can be copied.

```powershell
.\windows\build.ps1
```

On a Mac or Linux machine, `make -C windows test` runs the shared logic tests. Open `windows/CursorTokens.sln` in Visual Studio, choose the x64 platform, and deploy **CursorTokens.App**. The first deploy needs a test certificate whose subject is `CN=TX Labs`, matching `Package.appxmanifest`. In the packaging manifest designer, choose **Choose Certificate**, then **Create**, and set the publisher to `CN=TX Labs`. Trust that certificate when Windows asks.

Launch **Cursor Tokens** from the Start menu and sign in. Open the Widgets Board with Win+W, choose **Add widgets**, and pin **Cursor Usage**. The small size matches the weather widget; medium and large show the same card with more room.

The window refreshes every 5 minutes while it is open. While the Widgets Board is showing the widget, the provider also refreshes every 5 minutes. After both are closed, the next refresh happens when the board shows the widget again. The session stays in the per-user Cursor Tokens data folder and is not written into this repo.

The usage rules, cookie encoding, Adaptive Card, and package manifest are covered by `make -C windows test`. The WinUI window and the Widgets Board host were not launched from this repo’s macOS checkout.
