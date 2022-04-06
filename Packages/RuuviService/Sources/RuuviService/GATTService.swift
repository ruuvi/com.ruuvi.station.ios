import Foundation
import Future
import BTKit
import RuuviOntology

extension Notification.Name {
    public static let RuuviTagReadLogsOperationDidStart = Notification.Name("RuuviTagReadLogsOperationDidStart")
    public static let RuuviTagReadLogsOperationDidFail = Notification.Name("RuuviTagReadLogsOperationDidFail")
    public static let RuuviTagReadLogsOperationProgress = Notification.Name("RuuviTagReadLogsOperationProgress")
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

public enum RuuviTagReadLogsOperationProgressKey: String {
    case uuid
    case progress
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

    @discardableResult
    func stopGattSync(for uuid: String) -> Future<Bool, RuuviServiceError>
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

    @discardableResult
    public func stopGattSync(for uuid: String) -> Future<Bool, RuuviServiceError> {
        return stopGattSync(for: uuid)
    }
}
