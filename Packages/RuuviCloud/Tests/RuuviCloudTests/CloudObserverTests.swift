import Foundation
import XCTest
@testable import RuuviCloud

@MainActor final class CloudObserverTests: XCTestCase {
    func testObserversFilterMalformedEventsReplaceCallbacksAndStopIndividuallyOrTogether() {
        let manager = RuuviCloudRequestStateObserverManager.shared
        defer { manager.stopAllObservers() }
        let first = UUID().uuidString
        let second = UUID().uuidString
        var oldStates: [RuuviCloudRequestStateType] = []
        var newStates: [RuuviCloudRequestStateType] = []
        var otherStates: [RuuviCloudRequestStateType] = []
        manager.startObserving(for: nil) { _ in XCTFail("Nil identity observed") }
        manager.stopObserving(for: nil)
        manager.startObserving(for: first) { oldStates.append($0) }
        post(first, .loading)
        XCTAssertEqual(oldStates, [.loading])
        manager.startObserving(for: first) { newStates.append($0) }
        manager.startObserving(for: second) { otherStates.append($0) }
        post(first, .success)
        post(second, .failed)
        NotificationCenter.default.post(name: .RuuviCloudRequestStateDidChange, object: nil)
        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange, object: nil,
            userInfo: [RuuviCloudRequestStateKey.macId: first])
        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange, object: nil,
            userInfo: [RuuviCloudRequestStateKey.macId: first, RuuviCloudRequestStateKey.state: "bad"])
        XCTAssertEqual(oldStates, [.loading])
        XCTAssertEqual(newStates, [.success])
        XCTAssertEqual(otherStates, [.failed])
        manager.stopObserving(for: first)
        post(first, .complete)
        post(second, .complete)
        XCTAssertEqual(newStates, [.success])
        XCTAssertEqual(otherStates, [.failed, .complete])
        manager.stopAllObservers()
        post(second, .loading)
        XCTAssertEqual(otherStates, [.failed, .complete])
        manager.stopObserving(for: first)
    }

    private func post(_ id: String, _ state: RuuviCloudRequestStateType) {
        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange, object: nil,
            userInfo: [RuuviCloudRequestStateKey.macId: id, RuuviCloudRequestStateKey.state: state])
    }
}
