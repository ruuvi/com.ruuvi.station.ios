@testable import RuuviNotifier
import RuuviOntology
import XCTest

final class RuuviNotifierTests: XCTestCase {
    func testObserverOptionalAlertCallbackDefaultsToNoOp() {
        let observer = ObserverSpy()
        let notifier = NotifierStub()

        observer.ruuvi(
            notifier: notifier,
            alertType: .connection,
            isTriggered: true,
            for: "1234"
        )

        XCTAssertEqual(observer.requiredCallbackCount, 0)
    }

    func testLegacyClearMovementAlertHysteresisDefaultDoesNotInvokeNotifierImplementation() {
        let notifier = NotifierStub()

        notifier.clearMovementAlertHysteresis(for: "1234")

        XCTAssertEqual(notifier.clearMovementHysteresisCalls, 0)
    }
}

private final class ObserverSpy: RuuviNotifierObserver {
    var requiredCallbackCount = 0

    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        requiredCallbackCount += 1
    }
}

private final class NotifierStub: RuuviNotifier {
    var clearMovementHysteresisCalls = 0

    func process(record ruuviTag: RuuviTagSensorRecord, trigger: Bool) {}

    func processNetwork(record: RuuviTagSensorRecord, trigger: Bool, for identifier: MACIdentifier) {}

    func subscribe<T>(_ observer: T, to uuid: String) where T: RuuviNotifierObserver {}

    func isSubscribed<T>(_ observer: T, to uuid: String) -> Bool where T: RuuviNotifierObserver {
        false
    }

    func clearMovementHysteresis(for uuid: String) {
        clearMovementHysteresisCalls += 1
    }
}
