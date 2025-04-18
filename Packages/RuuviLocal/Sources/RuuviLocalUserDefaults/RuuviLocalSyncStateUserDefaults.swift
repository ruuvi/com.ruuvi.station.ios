import Foundation
import RuuviOntology

final class RuuviLocalSyncStateUserDefaults: RuuviLocalSyncState {
    private let syncStatusPrefix = "RuuviLocalSyncStateUserDefaults.syncState."
    private let syncStatusHistoryPrefix = "RuuviLocalSyncStateUserDefaults.syncStatusHistoryPrefix."
    private let syncDatePrefix = "RuuviLocalSyncStateUserDefaults.syncDate."
    private let syncDateAllIDKey = "RuuviLocalSyncStateUserDefaults.syncDateAllIDKey."
    private let fullHistorySyncPrefix = "RuuviLocalSyncStateUserDefaults.fullHistorySyncPrefix."
    private let gattSyncDatePrefix = "RuuviLocalSyncStateUserDefaults.gattSyncDate."
    private var syncingEnqueue: [AnyMACIdentifier] = []

    func setSyncStatus(_ status: NetworkSyncStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.syncStatus = status
        }
    }

    func setSyncStatusLatestRecord(_ status: NetworkSyncStatus, for macId: MACIdentifier) {
        UserDefaults.standard.set(status.rawValue, forKey: syncStatusPrefix + macId.mac)
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .NetworkSyncLatestDataDidChangeStatus, object: nil, userInfo: [
                    NetworkSyncStatusKey.status: status,
                    NetworkSyncStatusKey.mac: macId,
                ])
        }
    }

    func getSyncStatusLatestRecord(for macId: MACIdentifier) -> NetworkSyncStatus {
        let value = UserDefaults.standard.integer(forKey: syncStatusPrefix + macId.mac)
        return NetworkSyncStatus(rawValue: value) ?? .none
    }

    func setSyncStatusHistory(_ status: NetworkSyncStatus, for macId: MACIdentifier?) {
        guard let macId else { return }
        UserDefaults.standard.set(status.rawValue, forKey: syncStatusHistoryPrefix + macId.mac)
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .NetworkSyncHistoryDidChangeStatus, object: nil, userInfo: [
                    NetworkSyncStatusKey.status: status,
                    NetworkSyncStatusKey.mac: macId,
                ])
        }
    }

    func setSyncDate(_ date: Date?, for macId: MACIdentifier?) {
        guard let macId else { return }
        UserDefaults.standard.set(date, forKey: syncDatePrefix + macId.mac)
    }

    func getSyncDate(for macId: MACIdentifier?) -> Date? {
        guard let macId else { assertionFailure(); return nil }
        return UserDefaults.standard.value(forKey: syncDatePrefix + macId.mac) as? Date
    }

    func setGattSyncDate(_ date: Date?, for macId: MACIdentifier?) {
        guard let macId else { return }
        UserDefaults.standard.set(date, forKey: gattSyncDatePrefix + macId.mac)
    }

    func getGattSyncDate(for macId: MACIdentifier?) -> Date? {
        guard let macId else { assertionFailure(); return nil }
        return UserDefaults.standard.value(forKey: gattSyncDatePrefix + macId.mac) as? Date
    }

    func setSyncDate(_ date: Date?) {
        UserDefaults.standard.set(date, forKey: syncDateAllIDKey)
        setSyncStatus(.none)
    }

    func getSyncDate() -> Date? {
        UserDefaults.standard.value(forKey: syncDateAllIDKey) as? Date
    }

    func setDownloadFullHistory(for macId: MACIdentifier?, downloadFull: Bool?) {
        guard let macId else { return }
        if let downloadFull {
            UserDefaults.standard.set(downloadFull, forKey: fullHistorySyncPrefix + macId.mac)
        } else {
            UserDefaults.standard.removeObject(forKey: fullHistorySyncPrefix + macId.mac)
        }
    }

    func downloadFullHistory(for macId: MACIdentifier?) -> Bool? {
        guard let macId else { assertionFailure(); return nil }
        return UserDefaults.standard.value(forKey: fullHistorySyncPrefix + macId.mac) as? Bool
    }

    @UserDefault("RuuviLocalSyncStateUserDefaults.syncStatus", defaultValue: 0)
    private var syncStatusInt: Int

    var syncStatus: NetworkSyncStatus {
        get {
            NetworkSyncStatus(rawValue: syncStatusInt) ?? NetworkSyncStatus.none
        }
        set {
            syncStatusInt = newValue.rawValue
            NotificationCenter
                .default
                .post(name: .NetworkSyncDidChangeCommonStatus, object: self, userInfo: [
                    NetworkSyncStatusKey.status: newValue
                ])
        }
    }
}
