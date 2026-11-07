import BTKit
import XCTest
@testable import station

@MainActor final class ConnectionLifetimeTests: XCTestCase {
    func testStoppedAndReplacedBluetoothObserversCannotDeliverLateEvents() {
        let fixture = ConnectionContractFixture()
        fixture.service.startObservingConnections()
        let first = fixture.transport.callbacks[0]
        fixture.service.startObservingConnections()
        let second = fixture.transport.callbacks[1]
        XCTAssertEqual(fixture.transport.cancellations, 1)
        first(.poweredOff)
        XCTAssertTrue(fixture.delegate.states.isEmpty)
        second(.poweredOff)
        XCTAssertEqual(fixture.delegate.states.count, 1)
        fixture.service.stopObservingConnections()
        second(.unauthorized)
        XCTAssertEqual(fixture.delegate.states.count, 1)
        XCTAssertEqual(fixture.transport.cancellations, 2)
    }

    func testTransportCallbacksReachTheDelegateOnMainThread() async {
        let fixture = ConnectionContractFixture()
        fixture.service.startObservingConnections()
        defer { fixture.service.stopObservingConnections() }
        let callback = fixture.transport.callbacks[0]
        await Task.detached { callback(.poweredOff) }.value
        await waitForAppState("Bluetooth state delivered") { fixture.delegate.states.count == 1 }
        XCTAssertTrue(fixture.delegate.onMain)
    }
}
