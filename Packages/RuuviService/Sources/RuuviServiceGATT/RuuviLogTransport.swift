#if SWIFT_PACKAGE
    import RuuviService
#endif
import BTKit
import Foundation

/// The Bluetooth boundary for one log download. Persistence and queue ownership
/// stay in the service, independent of the central manager's callback threads.
protocol RuuviLogTransport: AnyObject {
    func read<T: AnyObject>(
        for observer: T, uuid: String, from: Date, service: BTRuuviNUSService,
        connectionTimeout: TimeInterval, serviceTimeout: TimeInterval,
        progress: @escaping (BTServiceProgress) -> Void,
        result: @escaping (T, Result<Progressable, BTError>) -> Void
    )
    func disconnect<T: AnyObject>(for observer: T, uuid: String)
}

final class BTKitLogTransport: RuuviLogTransport {
    private let background: BTBackground
    init(background: BTBackground) { self.background = background }
    func read<T: AnyObject>(
        for observer: T, uuid: String, from: Date, service: BTRuuviNUSService,
        connectionTimeout: TimeInterval, serviceTimeout: TimeInterval,
        progress: @escaping (BTServiceProgress) -> Void,
        result: @escaping (T, Result<Progressable, BTError>) -> Void
    ) {
        background.services.ruuvi.nus.log(
            for: observer, uuid: uuid, from: from, service: service,
            options: [
                .callbackQueue(.untouch), .connectionTimeout(connectionTimeout), .serviceTimeout(serviceTimeout),
            ],
            progress: progress, result: result)
    }
    func disconnect<T: AnyObject>(for observer: T, uuid: String) {
        background.services.ruuvi.nus.disconnect(for: observer, uuid: uuid, options: [], result: { _, _ in })
    }
}
