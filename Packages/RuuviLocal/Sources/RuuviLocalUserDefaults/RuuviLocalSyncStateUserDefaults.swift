import Foundation
import RuuviOntology
import RuuviLocal

final class RuuviLocalSyncStateUserDefaults: RuuviLocalSyncState {
    private let syncStatusPrefix = "RuuviLocalSyncStateUserDefaults.syncState."
    private let syncDatePrefix = "RuuviLocalSyncStateUserDefaults.syncDate."
    private let gattSyncDatePrefix = "RuuviLocalSyncStateUserDefaults.gattSyncDate."
    private var syncingEnqueue: [AnyMACIdentifier] = []

    func setSyncStatus(_ status: NetworkSyncStatus) {
        UserDefaults.standard.set(status.rawValue, forKey: syncStatusPrefix)
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .NetworkSyncDidChangeStatus, object: nil, userInfo: [
                    NetworkSyncStatusKey.status: status
                ])
        }
        switch status {
        case .complete, .onError:
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1),
                                          execute: { [weak self] in
                self?.setSyncStatus(.none)
            })
        case .syncing:
            DispatchQueue.main.async { [weak self] in
                self?.syncStatus = .syncing
            }
        case .none:
            DispatchQueue.main.async { [weak self] in
                self?.syncStatus = .none
            }
        }
    }

    func getSyncStatus() -> NetworkSyncStatus {
        let value = UserDefaults.standard.integer(forKey: syncStatusPrefix)
        return NetworkSyncStatus(rawValue: value) ?? .none
    }

    func setSyncDate(_ date: Date?, for macId: MACIdentifier?) {
        guard let macId = macId else { return }
        UserDefaults.standard.set(date, forKey: syncDatePrefix + macId.mac)
    }

    func getSyncDate(for macId: MACIdentifier?) -> Date? {
        guard let macId = macId else { assertionFailure(); return nil }
        return UserDefaults.standard.value(forKey: syncDatePrefix + macId.mac) as? Date
    }

    func setGattSyncDate(_ date: Date?, for macId: MACIdentifier?) {
        guard let macId = macId else { return }
        UserDefaults.standard.set(date, forKey: gattSyncDatePrefix + macId.mac)
    }

    func getGattSyncDate(for macId: MACIdentifier?) -> Date? {
        guard let macId = macId else { assertionFailure(); return nil }
        return UserDefaults.standard.value(forKey: gattSyncDatePrefix + macId.mac) as? Date
    }

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
