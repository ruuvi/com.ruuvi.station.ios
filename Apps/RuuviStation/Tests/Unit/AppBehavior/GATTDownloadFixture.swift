import BTKit
import Foundation
import RuuviOntology
import RuuviPool
import XCTest
@testable import RuuviService
@testable import station

@MainActor final class GATTDownloadFixture {
    let pool = AppPoolSpy()
    let radio = LogTransportSpy()
    let uuid = UUID().uuidString
    let from = Date(timeIntervalSince1970: 1_800_000_000)
    let service: GATTServiceQueue
    init(concurrent: Int = 3) {
        pool.allowRecordWrites = true
        service = GATTServiceQueue(ruuviPool: pool, transport: radio, maxConcurrentDownloads: concurrent)
    }
    func start(uuid: String? = nil, firmware: Int = 5) -> Task<Bool, Error> {
        Task { @MainActor in
            try await service.syncLogs(
                uuid: uuid ?? self.uuid, mac: "AA:BB:CC:DD:EE:FF", firmware: firmware,
                from: from, settings: nil, progress: nil, timeouts: .init(connection: 12, service: 34))
        }
    }
    func operation(progress: ((BTServiceProgress) -> Void)? = nil) -> RuuviTagReadLogsOperation {
        RuuviTagReadLogsOperation(
            uuid: uuid, mac: nil, firmware: 5, from: from, settings: nil,
            ruuviPool: pool, transport: radio, progress: progress)
    }
}

final class LogTransportSpy: RuuviLogTransport {
    struct Request {
        let uuid: String
        let from: Date
        let service: BTRuuviNUSService
        let connectionTimeout: TimeInterval
        let serviceTimeout: TimeInterval
        let progress: (BTServiceProgress) -> Void
        let receive: (Result<Progressable, BTError>) -> Void
    }
    private let lock = NSLock()
    private var storedRequests = [Request]()
    private var storedDisconnects = [String]()
    var requests: [Request] { lock.withLock { storedRequests } }
    var disconnects: [String] { lock.withLock { storedDisconnects } }
    func read<T: AnyObject>(
        for observer: T, uuid: String, from: Date, service: BTRuuviNUSService,
        connectionTimeout: TimeInterval, serviceTimeout: TimeInterval,
        progress: @escaping (BTServiceProgress) -> Void,
        result: @escaping (T, Result<Progressable, BTError>) -> Void
    ) {
        let request = Request(
            uuid: uuid, from: from, service: service, connectionTimeout: connectionTimeout,
            serviceTimeout: serviceTimeout, progress: progress,
            receive: { [weak observer] value in if let observer { result(observer, value) } })
        lock.withLock { storedRequests.append(request) }
    }
    func disconnect<T: AnyObject>(for observer: T, uuid: String) {
        lock.withLock { storedDisconnects.append(uuid) }
    }
}

final class LogNotificationRecorder {
    private(set) var notifications = [Notification]()
    private var tokens = [NSObjectProtocol]()
    init(uuid: String) {
        for name: Notification.Name in [
            .RuuviTagReadLogsOperationDidStart, .RuuviTagReadLogsOperationProgress,
            .RuuviTagReadLogsOperationDidFinish, .RuuviTagReadLogsOperationDidFail,
        ] {
            tokens.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let matches =
                        note.userInfo?.contains { key, value in
                            String(describing: key) == "uuid" && (value as? String) == uuid
                        } == true
                    if matches { self?.notifications.append(note) }
                })
        }
    }
    deinit { tokens.forEach(NotificationCenter.default.removeObserver) }
    func count(_ name: Notification.Name) -> Int { notifications.filter { $0.name == name }.count }
}
