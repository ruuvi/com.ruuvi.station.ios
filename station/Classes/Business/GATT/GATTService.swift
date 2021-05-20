import Foundation
import Future
import BTKit

protocol GATTService {

    func isSyncingLogs(with uuid: String) -> Bool

    // swiftlint:disable function_parameter_count
    @discardableResult
    func syncLogs(uuid: String,
                  mac: String?,
                  settings: SensorSettings?,
                  progress: ((BTServiceProgress) -> Void)?,
                  connectionTimeout: TimeInterval?,
                  serviceTimeout: TimeInterval?) -> Future<Bool, RUError>
    // swiftlint:enable function_parameter_count
}

extension GATTService {

    @discardableResult
    func syncLogs(uuid: String, mac: String?, settings: SensorSettings?) -> Future<Bool, RUError> {
        return syncLogs(uuid: uuid,
                        mac: mac,
                        settings: settings,
                        progress: nil,
                        connectionTimeout: nil,
                        serviceTimeout: nil)
    }

}
