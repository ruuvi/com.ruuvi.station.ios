import Foundation
import Future
import BTKit
import RuuviOntology

extension Notification.Name {
    public static let RuuviTagReadLogsOperationDidStart = Notification.Name("RuuviTagReadLogsOperationDidStart")
    public static let RuuviTagReadLogsOperationDidFail = Notification.Name("RuuviTagReadLogsOperationDidFail")
    public static let RuuviTagReadLogsOperationDidFinish = Notification.Name("RuuviTagReadLogsOperationDidFinish")
}

public enum RuuviTagReadLogsOperationDidStartKey: String {
    case uuid
    case fromDate
}

public enum RuuviTagReadLogsOperationDidFailKey: String {
    case uuid
    case error
}

public enum RuuviTagReadLogsOperationDidFinishKey: String {
    case uuid
    case logs
}

public protocol GATTService {
    func isSyncingLogs(with uuid: String) -> Bool

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    func syncLogs(
        uuid: String,
        mac: String?,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        connectionTimeout: TimeInterval?,
        serviceTimeout: TimeInterval?
    ) -> Future<Bool, RuuviServiceError>
}

extension GATTService {
    @discardableResult
    public func syncLogs(
        uuid: String,
        mac: String?,
        settings: SensorSettings?
    ) -> Future<Bool, RuuviServiceError> {
        return syncLogs(
            uuid: uuid,
            mac: mac,
            settings: settings,
            progress: nil,
            connectionTimeout: nil,
            serviceTimeout: nil
        )
    }
}
