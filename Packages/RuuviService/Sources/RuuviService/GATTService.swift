import BTKit
import Foundation
import Future
import RuuviOntology

public extension Notification.Name {
    static let RuuviTagReadLogsOperationDidStart = Notification.Name("RuuviTagReadLogsOperationDidStart")
    static let RuuviTagReadLogsOperationDidFail = Notification.Name("RuuviTagReadLogsOperationDidFail")
    static let RuuviTagReadLogsOperationProgress = Notification.Name("RuuviTagReadLogsOperationProgress")
    static let RuuviTagReadLogsOperationDidFinish = Notification.Name("RuuviTagReadLogsOperationDidFinish")
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
    func isSyncingLogsQueued(with uuid: String) -> Bool

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        connectionTimeout: TimeInterval?,
        serviceTimeout: TimeInterval?
    ) -> Future<Bool, RuuviServiceError>

    @discardableResult
    func stopGattSync(for uuid: String) -> Future<Bool, RuuviServiceError>
}

public extension GATTService {
    func isSyncingLogsQueued(with uuid: String) -> Bool {
        false
    }

    @discardableResult
    func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?
    ) -> Future<Bool, RuuviServiceError> {
        syncLogs(
            uuid: uuid,
            mac: mac,
            firmware: firmware,
            from: from,
            settings: settings,
            progress: nil,
            connectionTimeout: nil,
            serviceTimeout: nil
        )
    }

    @discardableResult
    func stopGattSync(for uuid: String) -> Future<Bool, RuuviServiceError> {
        stopGattSync(for: uuid)
    }
}
