#if SWIFT_PACKAGE
    import RuuviDaemon
#endif
import Foundation
import RuuviLocal
import RuuviService

/// Owns cancellable polling and sync tasks. A stopped or replaced session cannot restart itself.
final class RuuviDaemonCloudSyncWorker: RuuviDaemonCloudSync {
    private let pullInterval: () -> TimeInterval
    private let migrationInProgress: () -> Bool
    private let cloudSyncService: RuuviServiceCloudSync
    private let retryDelay: TimeInterval
    private let lock = NSLock()
    private var running = false
    private var epoch = UUID()
    private var pollingTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var latestTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var refreshID: UUID?
    private var latestID: UUID?
    private var retryID: UUID?

    convenience init(
        localSettings: RuuviLocalSettings,
        localSyncState _: RuuviLocalSyncState,
        cloudSyncService: RuuviServiceCloudSync
    ) {
        self.init(
            pullInterval: { TimeInterval(localSettings.networkPullIntervalSeconds) },
            migrationInProgress: { localSettings.signalVisibilityMigrationInProgress },
            cloudSyncService: cloudSyncService)
    }

    init(
        pullInterval: @escaping () -> TimeInterval,
        migrationInProgress: @escaping () -> Bool,
        cloudSyncService: RuuviServiceCloudSync,
        retryDelay: TimeInterval = 5
    ) {
        self.pullInterval = pullInterval
        self.migrationInProgress = migrationInProgress
        self.cloudSyncService = cloudSyncService
        self.retryDelay = retryDelay
    }

    deinit { stop() }

    func start() {
        lock.withLock {
            guard !running else { return }
            running = true
            let session = epoch
            pollingTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let delay = self?.poll(session: session) else { return }
                    do { try await Task.sleep(nanoseconds: delay) } catch { return }
                }
            }
        }
    }

    func stop() {
        let tasks = lock.withLock {
            let tasks = [pollingTask, refreshTask, latestTask, retryTask].compactMap { $0 }
            running = false
            epoch = UUID()
            pollingTask = nil
            refreshTask = nil
            latestTask = nil
            retryTask = nil
            refreshID = nil
            latestID = nil
            retryID = nil
            return tasks
        }
        tasks.forEach { $0.cancel() }
    }

    func isRunning() -> Bool { lock.withLock { running } }

    func refreshImmediately() { requestRefresh() }

    func refreshLatestRecord() {
        lock.withLock {
            guard !migrationInProgress(), latestTask == nil else { return }
            let identifier = UUID()
            latestID = identifier
            latestTask = Task { @MainActor [weak self, cloudSyncService] in
                guard self?.lock.withLock({ self?.latestID == identifier }) == true else { return }
                defer {
                    self?.lock.withLock {
                        guard self?.latestID == identifier else { return }
                        self?.latestID = nil
                        self?.latestTask = nil
                    }
                }
                _ = try? await cloudSyncService.refreshLatestRecord()
            }
        }
    }

    private func poll(session: UUID) -> UInt64? {
        let delay = lock.withLock { running && epoch == session ? Self.nanoseconds(pullInterval()) : nil }
        guard let delay else { return nil }
        requestRefresh(expectedEpoch: session)
        return delay
    }

    private func requestRefresh(expectedEpoch: UUID? = nil) {
        lock.withLock {
            guard expectedEpoch == nil || epoch == expectedEpoch, refreshTask == nil else { return }
            if migrationInProgress() {
                scheduleRetry()
                return
            }
            retryTask?.cancel()
            retryTask = nil
            retryID = nil
            let identifier = UUID()
            refreshID = identifier
            refreshTask = Task { @MainActor [weak self, cloudSyncService] in
                guard self?.lock.withLock({ self?.refreshID == identifier }) == true else { return }
                defer {
                    self?.lock.withLock {
                        guard self?.refreshID == identifier else { return }
                        self?.refreshID = nil
                        self?.refreshTask = nil
                    }
                }
                _ = try? await cloudSyncService.syncAllRecords()
            }
        }
    }

    /// Called with the state lock held; all retries belong to the current session.
    private func scheduleRetry() {
        guard retryTask == nil else { return }
        let identifier = UUID()
        let session = epoch
        let delay = Self.nanoseconds(retryDelay)
        retryID = identifier
        retryTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: delay) } catch { return }
            self?.retry(identifier: identifier, session: session)
        }
    }

    private func retry(identifier: UUID, session: UUID) {
        let shouldRefresh = lock.withLock {
            guard retryID == identifier, epoch == session else { return false }
            retryID = nil
            retryTask = nil
            return true
        }
        if shouldRefresh { requestRefresh(expectedEpoch: session) }
    }

    private static func nanoseconds(_ interval: TimeInterval) -> UInt64 {
        let value = interval * 1_000_000_000
        guard value.isFinite, value >= 1, value < Double(UInt64.max) else { return 60_000_000_000 }
        return UInt64(value)
    }
}
