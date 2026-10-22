import Foundation
import os

private let refreshLogger = Logger(subsystem: "org.tx.cursortokenwidget", category: "refresh")

enum UsageRefresh {
    static func refresh(now: Date = Date()) async -> UsageSnapshot {
        guard let session = SessionStore.load() else {
            let snapshot = UsageSnapshot.signedOut()
            SnapshotStore.save(snapshot)
            return snapshot
        }

        let previous = SnapshotStore.load()
        let client = CursorClient(sessionValue: session)
        do {
            let summary = try await client.fetchSummary()
            async let emailResult = client.fetchEmail()
            async let todayResult = client.fetchTotalTokens(from: DateWindows.start(daysAgo: 0, now: now), to: now)
            async let weekResult = client.fetchTotalTokens(from: DateWindows.start(daysAgo: 6, now: now), to: now)
            async let monthResult = client.fetchTotalTokens(from: DateWindows.start(daysAgo: 29, now: now), to: now)

            let snapshot = UsageSnapshot(
                isSignedIn: true,
                cursorModelsPercent: summary.individualUsage?.plan?.autoPercentUsed?.value,
                otherModelsPercent: summary.individualUsage?.plan?.apiPercentUsed?.value,
                todayTokens: try? await todayResult,
                weekTokens: try? await weekResult,
                monthTokens: try? await monthResult,
                onDemandEnabled: summary.individualUsage?.onDemand?.enabled,
                onDemandUsedCents: summary.individualUsage?.onDemand?.used?.value,
                onDemandLimitCents: summary.individualUsage?.onDemand?.limit?.value,
                membership: summary.membershipType,
                email: try? await emailResult,
                updatedAt: now,
                error: nil
            )
            SnapshotStore.save(snapshot)
            return snapshot
        } catch CursorAPIError.unauthorized {
            SessionStore.delete()
            let snapshot = UsageSnapshot.signedOut(error: "Session expired. Sign in again.")
            SnapshotStore.save(snapshot)
            return snapshot
        } catch {
            refreshLogger.error("Usage refresh failed: \(error.localizedDescription, privacy: .public)")
            var snapshot = previous?.isSignedIn == true ? previous! : UsageSnapshot.emptySignedIn()
            snapshot.error = "Couldn't reach Cursor. Showing the last update."
            SnapshotStore.save(snapshot)
            return snapshot
        }
    }
}
