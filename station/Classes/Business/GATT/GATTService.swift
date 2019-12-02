import Foundation
import Future
import BTKit

protocol GATTService {

    func isSyncingLogs(with uuid: String) -> Bool

    @discardableResult
    func syncLogs(with uuid: String,
                  progress: ((BTServiceProgress) -> Void)?,
                  connectionTimeout: TimeInterval?,
                  serviceTimeout: TimeInterval?) -> Future<Bool, RUError>
}

extension GATTService {

    @discardableResult
    func syncLogs(with uuid: String) -> Future<Bool, RUError> {
        return syncLogs(with: uuid, progress: nil, connectionTimeout: nil, serviceTimeout: nil)
    }

}
