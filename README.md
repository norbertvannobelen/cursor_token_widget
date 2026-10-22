# Cursor Tokens

A small macOS app and desktop widget for the same Cursor usage figures as the dashboard.

- **Cursor Models** and **Other Models** allowance, as a percent and a bar
- **Today**, **7 days**, and **30 days** token totals
- Refreshes every 5 minutes while the app is running, and the widget asks macOS to refresh on that same interval

The widget is the small system size, the same class as the small Weather widget.

## Sign in

Open **Cursor Tokens** and use one of these:

1. **Use the account signed in to Cursor** reads the session already stored by the Cursor app on this Mac. From Terminal, `open -a "Cursor Tokens" --args --use-local-cursor` does the same thing.
2. **Sign in with email or SSO** opens Cursor’s site inside the app and keeps the session cookie.
3. **Paste a session token** if a provider blocks the embedded browser. In Safari, open [cursor.com/dashboard](https://cursor.com/dashboard), then copy the `WorkosCursorSessionToken` cookie value.

The session stays in the app’s private App Group container. It is not written into this repo.

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

You can also open the app from the menu bar. The menu bar title shows the two allowance percents after you sign in.

## Refresh

The app refreshes every 5 minutes and updates the widget. The widget’s own timeline also requests a refresh every 5 minutes, so the numbers keep moving when the window is closed. macOS can delay a widget refresh while the Mac is idle. Quitting the app from the menu bar stops the in-app timer; the widget still refreshes on its own schedule.
