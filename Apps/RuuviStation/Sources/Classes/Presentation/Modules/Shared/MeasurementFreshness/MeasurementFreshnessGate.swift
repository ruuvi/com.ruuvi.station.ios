import Foundation
import RuuviLocal
import RuuviService

/// Startup protection is bounded even when a refresh never starts or never completes.
@MainActor
final class MeasurementFreshnessGate {
    static let shared = MeasurementFreshnessGate()
    static let localDiscoveryGraceSeconds: TimeInterval = 30
    static let maximumCloudWaitSeconds: TimeInterval = 60

    private let notificationCenter: NotificationCenter
    private let uptime: () -> TimeInterval
    private var foregroundStartedAt: TimeInterval
    private var cloudSyncExpected = false
    private var initialCloudSyncCompleted = false
    private var activeSyncs: [UUID: TimeInterval] = [:]
    private var committedDates: [String: Date] = [:]
    private var syncToken: NSObjectProtocol?
    private var logoutToken: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.notificationCenter = notificationCenter
        self.uptime = uptime
        foregroundStartedAt = uptime()
        syncToken = notificationCenter.addObserver(
            forName: RuuviCloudSyncEvent.notification, object: nil, queue: .main
        ) { [weak self] notification in
            let value = notification.userInfo?[RuuviCloudSyncEvent.userInfoKey]
            guard let event = value as? RuuviCloudSyncEvent else { return }
            MainActor.assumeIsolated { self?.receive(event) }
        }
        logoutToken = notificationCenter.addObserver(
            forName: .RuuviAuthServiceDidLogout, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cloudSyncExpected = false
                self?.initialCloudSyncCompleted = false
                self?.activeSyncs.removeAll()
                self?.committedDates.removeAll()
            }
        }
    }

    func beginForegroundSession(expectingCloudSync: Bool) {
        foregroundStartedAt = uptime()
        cloudSyncExpected = expectingCloudSync
        initialCloudSyncCompleted = false
        committedDates.removeAll()
        expireOldOperations()
    }

    func shouldShowWarning(
        for snapshot: RuuviTagCardSnapshot?, timeoutSeconds: Int, now: Date = Date()
    ) -> Bool {
        guard let snapshot, RuuviMeasurementFreshness.isStale(
            lastUpdated: snapshot.lastUpdated, timeoutSeconds: timeoutSeconds, now: now
        ) else { return false }
        let elapsed = uptime() - foregroundStartedAt
        // Claimed/cloud sensors can also be discovered over Bluetooth on this launch.
        guard elapsed >= Self.localDiscoveryGraceSeconds else { return false }
        let committedDate = snapshot.identifierData.mac.flatMap { committedDates[$0.mac.uppercased()] }
        let usesCloud = snapshot.metadata.isCloud || snapshot.displayData.source == .ruuviNetwork
            || committedDate != nil
        guard usesCloud, cloudSyncExpected else { return true }
        if elapsed >= Self.maximumCloudWaitSeconds {
            expireOldOperations()
            return true
        }
        guard initialCloudSyncCompleted else { return false }
        if let committedDate,
           (snapshot.lastUpdated ?? .distantPast) < committedDate {
            return false
        }
        return true
    }

    private func receive(_ event: RuuviCloudSyncEvent) {
        expireOldOperations()
        switch event {
        case .started(let id):
            cloudSyncExpected = true
            activeSyncs[id] = uptime()
        case .recordsSaved(let dates):
            guard cloudSyncExpected else { return }
            for (mac, date) in dates {
                let key = mac.uppercased()
                committedDates[key] = max(committedDates[key] ?? .distantPast, date)
            }
        case .finished(let id):
            guard activeSyncs.removeValue(forKey: id) != nil else { return }
            if activeSyncs.isEmpty { initialCloudSyncCompleted = true }
        }
    }

    private func expireOldOperations() {
        let cutoff = uptime() - Self.maximumCloudWaitSeconds
        activeSyncs = activeSyncs.filter { $0.value > cutoff }
    }

    deinit {
        if let syncToken { notificationCenter.removeObserver(syncToken) }
        if let logoutToken { notificationCenter.removeObserver(logoutToken) }
    }
}
