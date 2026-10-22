import Foundation
import WidgetKit

@MainActor
final class UsageModel: ObservableObject {
    @Published var snapshot: UsageSnapshot
    @Published var isRefreshing = false

    private var timer: Timer?
    private var started = false

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

    func signOut() {
        SessionStore.delete()
        WebSessionCleaner.clear()
        snapshot = .signedOut()
        SnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
