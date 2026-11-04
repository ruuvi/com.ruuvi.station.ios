#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviCloud
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import BTKit
import Foundation
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
    case serviceProgress
}

public enum RuuviTagReadLogsOperationDidFinishKey: String {
    case uuid
    case logs
}

public struct GATTServiceTimeouts {
    public let connection: TimeInterval?
    public let service: TimeInterval?

    public init(connection: TimeInterval? = nil, service: TimeInterval? = nil) {
        self.connection = connection
        self.service = service
    }
}

public protocol GATTService {
    func isSyncingLogs() -> Bool
    func isSyncingLogs(with uuid: String) -> Bool
    func isSyncingLogsQueued(with uuid: String) -> Bool
    func syncProgress(with uuid: String) -> BTServiceProgress?

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        timeouts: GATTServiceTimeouts
    ) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func stopGattSync(for uuid: String) async throws(RuuviServiceError) -> Bool
}

public extension GATTService {
    func isSyncingLogsQueued(with _: String) -> Bool {
        false
    }

    func syncProgress(with _: String) -> BTServiceProgress? {
        nil
    }

    @discardableResult
    func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?
    ) async throws(RuuviServiceError) -> Bool {
        try await syncLogs(
            uuid: uuid,
            mac: mac,
            firmware: firmware,
            from: from,
            settings: settings,
            progress: nil,
            timeouts: GATTServiceTimeouts()
        )
    }

}
