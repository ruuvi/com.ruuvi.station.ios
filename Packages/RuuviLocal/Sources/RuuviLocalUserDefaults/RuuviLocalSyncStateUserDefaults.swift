import Foundation
import RuuviOntology
import RuuviLocal

final class RuuviLocalSyncStateUserDefaults: RuuviLocalSyncState {
    private let syncStatusPrefix = "RuuviLocalSyncStateUserDefaults.syncState."
    private let syncDatePrefix = "RuuviLocalSyncStateUserDefaults.syncDate."
    private let latestSyncDateUDKey = "RuuviLocalSyncStateUserDefaults.latestSyncDate."
    private var syncingEnqueue: [AnyMACIdentifier] = []

    func setSyncStatus(_ status: NetworkSyncStatus, for macId: MACIdentifier) {
        UserDefaults.standard.set(status.rawValue, forKey: syncStatusPrefix + macId.mac)
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .NetworkSyncDidChangeStatus, object: nil, userInfo: [
                    NetworkSyncStatusKey.mac: macId,
                    NetworkSyncStatusKey.status: status
                ])
        }
        switch status {
        case .complete, .onError:
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1),
                                          execute: { [weak self] in
                self?.setSyncStatus(.none, for: macId)
            })
        case .syncing:
            DispatchQueue.main.async { [weak self] in
                if self?.syncingEnqueue.isEmpty ?? false {
                    self?.syncStatus = .syncing
                }
                self?.syncingEnqueue.append(macId.any)
            }
        case .none:
            DispatchQueue.main.async { [weak self] in
                self?.syncingEnqueue.removeAll(where: {$0 == macId.any})
                if self?.syncingEnqueue.isEmpty ?? false {
                    self?.syncStatus = .none
                }
            }
        }
    }

    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus {
        let value = UserDefaults.standard.integer(forKey: syncStatusPrefix + macId.mac)
        return NetworkSyncStatus(rawValue: value) ?? .none
    }

    func setSyncDate(_ date: Date?, for macId: MACIdentifier?) {
        guard let macId = macId else { return }
        UserDefaults.standard.set(date, forKey: syncDatePrefix + macId.mac)
        if let date = date {
            if let latestSyncDate = latestSyncDate {
                if date > latestSyncDate {
                    self.latestSyncDate = date
                }
            } else {
                self.latestSyncDate = date
            }
        }
    }

    func getSyncDate(for macId: MACIdentifier?) -> Date? {
        guard let macId = macId else { assertionFailure(); return nil }
        return UserDefaults.standard.value(forKey: syncDatePrefix + macId.mac) as? Date
    }

    @UserDefault("RuuviLocalSyncStateUserDefaults.latestSyncDate", defaultValue: nil)
    var latestSyncDate: Date?

    @UserDefault("RuuviLocalSyncStateUserDefaults.syncStatus", defaultValue: 0)
    private var syncStatusInt: Int

    var syncStatus: NetworkSyncStatus {
        get {
            return NetworkSyncStatus(rawValue: syncStatusInt) ?? NetworkSyncStatus.none
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
