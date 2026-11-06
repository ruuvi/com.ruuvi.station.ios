import Foundation
import RuuviCloud
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardsAlertsLifecycleTests: XCTestCase {
    func testStartBuildsSectionsAndDeliveryPromptAndRoutesItsDestination() async throws {
        let fixture = CardsAlertsFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        XCTAssertEqual(fixture.view.configured.last, fixture.snapshot.id)
        XCTAssertFalse(fixture.view.sections.last?.isEmpty ?? true)
        fixture.services.data.measurements.settings.saveHeartbeats = false
        fixture.presenter.viewWillAppear()
        XCTAssertEqual(fixture.view.prompts.last??.destination, .backgroundScanning)
        fixture.presenter.viewDidTapAlertDeliveryPrompt(destination: .backgroundScanning)
        fixture.presenter.viewDidTapAlertDeliveryPrompt(destination: .sensorSettings)
        XCTAssertEqual(fixture.output.destinations, [.backgroundScanning, .sensorSettings])
        fixture.services.data.measurements.settings.saveHeartbeats = true
        fixture.presenter.viewWillAppear()
        XCTAssertNil(fixture.view.prompts.last!)
    }

    func testQueuedSnapshotFromThePreviousSensorCannotReplaceTheNewConfiguration() async throws {
        let fixture = CardsAlertsFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.view.configured.removeAll()
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .snapshotUpdated(fixture.snapshot, invalidateLayout: true))
        let other = RuuviTagCardSnapshot.create(
            id: "other", name: "Other", luid: UUID().uuidString.luid,
            mac: "00:11:22:33:44:55".mac, serviceUUID: nil, isCloud: false, isOwner: true,
            isConnectable: true, version: 5)
        fixture.presenter.configure(with: other, sensor: nil, settings: nil)
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.view.configured.isEmpty)
    }

    func testStoppingRejectsQueuedSnapshotAndCloudActivityCallbacks() async throws {
        let fixture = CardsAlertsFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.view.configured.removeAll()
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .alertSnapshotUpdated(fixture.snapshot))
        fixture.presenter.stop()
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.view.configured.isEmpty)
        post(.loading, mac: fixture.sensor.macId!.value)
        XCTAssertTrue(fixture.activity.shown.isEmpty)
    }

    func testCloudActivityTracksOnlyTheCurrentSensorAndStopsWhenThePresenterStops() async throws {
        let fixture = CardsAlertsFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let mac = fixture.sensor.macId!.value
        post(.loading, mac: "unrelated")
        XCTAssertTrue(fixture.activity.shown.isEmpty)
        post(.loading, mac: mac)
        post(.success, mac: mac)
        post(.failed, mac: mac)
        post(.complete, mac: mac)
        XCTAssertEqual(fixture.activity.shown.count, 1)
        XCTAssertEqual(fixture.activity.updates.count, 2)
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
        fixture.presenter.stop()
        post(.loading, mac: mac)
        XCTAssertEqual(fixture.activity.shown.count, 1)
    }

    private func post(_ state: RuuviCloudRequestStateType, mac: String) {
        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange, object: nil,
            userInfo: [RuuviCloudRequestStateKey.macId: mac, RuuviCloudRequestStateKey.state: state])
    }
}
