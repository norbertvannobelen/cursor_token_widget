import Foundation

extension Notification.Name {
    static let menuBarPreferenceChanged = Notification.Name("org.tx.cursortokenwidget.menuBar.local")
}

enum MenuBarPreference {
    static let notificationName = "org.tx.cursortokenwidget.menuBar"
    private static let account = "menu-bar"
    private static var observing = false

    static func isEnabled(stored: String?) -> Bool {
        stored == "1"
    }

    static func storedValue(enabled: Bool) -> String {
        enabled ? "1" : "0"
    }

    static func isEnabled() -> Bool {
        guard let data = KeychainStore.load(account: account),
              let stored = String(data: data, encoding: .utf8) else {
            return false
        }
        return isEnabled(stored: stored.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func setEnabled(_ enabled: Bool) {
        guard isEnabled() != enabled else { return }
        KeychainStore.save(Data(storedValue(enabled: enabled).utf8), account: account)
        postChange()
    }

    static func startObserving() {
        guard !observing else { return }
        observing = true
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .menuBarPreferenceChanged, object: nil)
                }
            },
            notificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private static func postChange() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName as CFString),
            nil,
            nil,
            true
        )
    }
}
