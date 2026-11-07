import RuuviOntology
import XCTest
@testable import station

@MainActor final class SensorRemovalContractTests: XCTestCase {
    func testRemovalRequiresConfirmationAndForwardsTheExactHistoryChoiceAndSensor() async {
        for removeHistory in [false, true] {
            let fixture = RemovalFixture()
            defer { fixture.measurements.cleanup() }
            fixture.configure()
            fixture.presenter?.viewDidLoad()
            XCTAssertEqual(fixture.view.ownerships.count, 1)
            XCTAssertEqual(fixture.view.ownerships.first, fixture.measurements.sensor.ownership)
            fixture.presenter?.viewDidTriggerRemoveTag()
            XCTAssertEqual(fixture.view.confirmations, 1)
            XCTAssertTrue(fixture.ownership.removals.isEmpty)
            fixture.presenter?.viewDidConfirmTagRemoval(with: removeHistory)
            await waitForAppState("sensor removed") { fixture.output.removed.count == 1 }
            XCTAssertEqual(fixture.ownership.removals.first?.0.id, fixture.measurements.sensor.id)
            XCTAssertEqual(fixture.ownership.removals.first?.1, removeHistory)
            XCTAssertEqual(fixture.output.removed.first?.1, fixture.measurements.sensor.id)
            XCTAssertTrue(fixture.output.removed.first?.0 === fixture.presenter)
            XCTAssertTrue(fixture.errors.errors.isEmpty)
        }
    }

    func testRemovalFailureReportsAnErrorAndRetryCanSucceed() async {
        let fixture = RemovalFixture()
        defer { fixture.measurements.cleanup() }
        fixture.configure()
        fixture.ownership.removalFailure = .failedToParseNetworkResponse
        fixture.presenter?.viewDidConfirmTagRemoval(with: false)
        await waitForAppState("removal failed") { fixture.errors.errors.count == 1 }
        XCTAssertTrue(fixture.output.removed.isEmpty)
        fixture.ownership.removalFailure = nil
        fixture.presenter?.viewDidConfirmTagRemoval(with: true)
        await waitForAppState("removal retried") { fixture.output.removed.count == 1 }
        XCTAssertEqual(fixture.ownership.removals.map(\.1), [false, true])
    }

    func testUnconfiguredModulesNeverStartRemovalAndDismissalCompletesOnce() {
        let fixture = RemovalFixture()
        defer { fixture.measurements.cleanup() }
        fixture.presenter?.viewDidLoad()
        fixture.presenter?.viewDidConfirmTagRemoval(with: true)
        XCTAssertTrue(fixture.view.ownerships.isEmpty)
        XCTAssertTrue(fixture.ownership.removals.isEmpty)
        var completed = 0
        fixture.presenter?.dismiss { completed += 1 }
        fixture.presenter?.viewDidDismiss()
        XCTAssertEqual(fixture.router.dismissals, 2)
        XCTAssertEqual(completed, 1)
        XCTAssertTrue(fixture.output.removed.isEmpty)
    }

    func testFinishingAfterPresenterReleaseDoesNotSendNavigationOrErrors() async {
        let fixture = RemovalFixture()
        defer { fixture.measurements.cleanup() }
        fixture.configure()
        var release: CheckedContinuation<Void, Never>?
        fixture.ownership.beforeRemove = { await withCheckedContinuation { release = $0 } }
        fixture.presenter?.viewDidConfirmTagRemoval(with: false)
        await waitForAppState("removal waiting") { release != nil }
        weak var released = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(released)
        release?.resume()
        await flushAppBindings()
        XCTAssertTrue(fixture.output.removed.isEmpty)
        XCTAssertTrue(fixture.errors.errors.isEmpty)
    }
}

@MainActor private final class RemovalFixture {
    let measurements = MeasurementFixture()
    let ownership = ShareOwnershipSpy()
    let errors = OffsetErrorSpy()
    let view = RemovalViewSpy()
    let output = RemovalOutputSpy()
    let router = RemovalRouterSpy()
    var presenter: SensorRemovalPresenter? = SensorRemovalPresenter()
    init() {
        ownership.allowRemovals = true
        presenter?.view = view
        presenter?.router = router
        presenter?.ruuviOwnershipService = ownership
        presenter?.errorPresenter = errors
        presenter?.settings = measurements.settings
    }
    func configure() { presenter?.configure(ruuviTag: measurements.sensor, output: output) }
}
private final class RemovalViewSpy: SensorRemovalViewInput {
    var ownerships = [SensorOwnership]()
    var confirmations = 0
    func updateView(ownership: SensorOwnership) { ownerships.append(ownership) }
    func showHistoryDataRemovalConfirmationDialog() { confirmations += 1 }
}
private final class RemovalOutputSpy: SensorRemovalModuleOutput {
    var removed = [(SensorRemovalModuleInput, String)]()
    func sensorRemovalDidRemoveTag(module: SensorRemovalModuleInput, ruuviTag: RuuviTagSensor) {
        removed.append((module, ruuviTag.id))
    }
    func sensorRemovalDidDismiss(module: SensorRemovalModuleInput) {}
}
private final class RemovalRouterSpy: SensorRemovalRouterInput {
    var dismissals = 0
    func dismiss(completion: (() -> Void)?) { dismissals += 1; completion?() }
}
