@testable import RuuviCloud
import XCTest

final class RuuviCloudTests: XCTestCase {
    override func tearDown() {
        RuuviCloudRequestStateObserverManager.shared.stopAllObservers()
        super.tearDown()
    }

    func testObserverReceivesOnlyMatchingMacIdUpdates() {
        let expectation = expectation(description: "matching states observed")
        expectation.expectedFulfillmentCount = 2
        var states: [RuuviCloudRequestStateType] = []

        RuuviCloudRequestStateObserverManager.shared.startObserving(for: "AA:BB:CC") { state in
            states.append(state)
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange,
            object: nil,
            userInfo: [
                RuuviCloudRequestStateKey.macId: "11:22:33",
                RuuviCloudRequestStateKey.state: RuuviCloudRequestStateType.failed,
            ]
        )
        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange,
            object: nil,
            userInfo: [
                RuuviCloudRequestStateKey.macId: "AA:BB:CC",
                RuuviCloudRequestStateKey.state: RuuviCloudRequestStateType.loading,
            ]
        )
        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange,
            object: nil,
            userInfo: [
                RuuviCloudRequestStateKey.macId: "AA:BB:CC",
                RuuviCloudRequestStateKey.state: RuuviCloudRequestStateType.success,
            ]
        )

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(states, [.loading, .success])
    }

    func testStartingObservationAgainReplacesPreviousObserver() {
        let expectation = expectation(description: "replacement observer called")
        var firstObserverCalls = 0
        var secondObserverCalls = 0

        RuuviCloudRequestStateObserverManager.shared.startObserving(for: "AA:BB:CC") { _ in
            firstObserverCalls += 1
        }
        RuuviCloudRequestStateObserverManager.shared.startObserving(for: "AA:BB:CC") { _ in
            secondObserverCalls += 1
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange,
            object: nil,
            userInfo: [
                RuuviCloudRequestStateKey.macId: "AA:BB:CC",
                RuuviCloudRequestStateKey.state: RuuviCloudRequestStateType.complete,
            ]
        )

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(firstObserverCalls, 0)
        XCTAssertEqual(secondObserverCalls, 1)
    }
}
