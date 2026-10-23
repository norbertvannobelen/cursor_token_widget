import AppKit
import Foundation
import ServiceManagement
import WidgetKit

@MainActor
final class UsageModel: ObservableObject {
    @Published var snapshot: UsageSnapshot
    @Published var isRefreshing = false
    @Published var showsMenuBarIcon = false
    @Published var showingWidgetHelp = false

    private var timer: Timer?
    private var started = false
    private var menuBarReady = false

    init() {
        snapshot = SnapshotStore.load() ?? .signedOut()
    }

    func start() {
        guard !started else { return }
        started = true
        let timer = Timer(timeInterval: UsageTiming.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        showsMenuBarIcon = MenuBarPreference.isEnabled()
        MenuBarPreference.startObserving()
        NotificationCenter.default.addObserver(
            forName: .menuBarPreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncMenuBarService()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.menuBarReady = true
                self?.syncMenuBarService()
            }
        }
        if CommandLine.arguments.contains("--use-local-cursor") {
            useLocalCursorAccount()
        } else {
            Task { await refresh() }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        snapshot = await UsageRefresh.refresh()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func useLocalCursorAccount() {
        do {
            let session = try CursorLocalSession.loadSession()
            SessionStore.save(session)
            Task { await refresh() }
        } catch {
            let updated = UsageSnapshot.signedOut(error: error.localizedDescription)
            snapshot = updated
            SnapshotStore.save(updated)
        }
    }

    func signIn(session: String) {
        let normalized = SessionCookie.normalizeStored(session)
        guard normalized.contains("::") else {
            var updated = snapshot
            updated.error = "That session token doesn't look complete."
            snapshot = updated
            return
        }
        SessionStore.save(normalized)
        Task { await refresh() }
    }

    func setMenuBarIconEnabled(_ enabled: Bool) {
        MenuBarPreference.setEnabled(enabled)
        if showsMenuBarIcon != enabled {
            showsMenuBarIcon = enabled
        }
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try? service.register()
            }
            return
        }
        if service.status == .enabled {
            try? service.unregister()
        }
    }

    func syncMenuBarService() {
        guard menuBarReady else { return }
        let app = NSApplication.shared
        let enabled = MenuBarPreference.isEnabled()
        if showsMenuBarIcon != enabled {
            showsMenuBarIcon = enabled
        }
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try? service.register()
            }
            return
        }
        if service.status == .enabled {
            try? service.unregister()
        }
        let hasWindow = app.windows.contains { $0.isVisible && $0.canBecomeMain }
        if app.activationPolicy() == .accessory && !hasWindow {
            app.terminate(nil)
        }
    }

    func signOut() {
        SessionStore.delete()
        WebSessionCleaner.clear()
        snapshot = .signedOut()
        SnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
