import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class DevicesPresenterContractTests: XCTestCase {
    func testAppearRefreshesDevicesAndMapsTokenMetadataWithoutInventingMissingValues() async throws {
        let presenter = DevicesPresenter()
        let interactor = DevicesInteractorSpy()
        presenter.interactor = interactor
        let view = try XCTUnwrap(presenter.viewController as? DevicesTableViewController)
        XCTAssertTrue(presenter.viewController === view)
        let host = try AppViewHost(view)
        defer { host.close() }
        let fetched = interactor.fetches
        presenter.viewWillAppear()
        XCTAssertEqual(interactor.fetches, fetched + 1)
        presenter.interactorDidUpdate(tokens: [
            RuuviCloudPNTokenStruct(id: 42, lastAccessed: 1000, name: "Phone 🌿"), RuuviCloudPNTokenStruct(id: 73),
        ])
        await waitForAppState("device token rows") { view.tableView.numberOfRows(inSection: 0) == 2 }
        XCTAssertEqual(view.viewModels.map { $0.id.value }, [42, 73])
        XCTAssertEqual(view.viewModels.first?.name.value, "Phone 🌿")
        XCTAssertEqual(view.viewModels.first?.lastAccessed.value, 1000)
        XCTAssertNil(view.viewModels.last?.name.value)
        XCTAssertNil(view.viewModels.last?.lastAccessed.value)
        presenter.viewDidTapDevice(viewModel: view.viewModels[0])
        let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, "42")
        await withCheckedContinuation { done in view.dismiss(animated: false) { done.resume() } }
        presenter.interactorDidUpdate(tokens: [])
        await waitForAppState("empty token list") { view.tableView.numberOfRows(inSection: 0) == 0 }
        presenter.interactorDidError(
            .networking(NSError(domain: "Offline", code: 1, userInfo: [NSLocalizedDescriptionKey: "No connection"])))
        XCTAssertEqual((view.presentedViewController as? UIAlertController)?.message, "No connection")
    }

    func testPresenterDoesNotRetainAClosedDeviceScreenAndCanCreateAReplacement() {
        let presenter = DevicesPresenter()
        presenter.interactor = DevicesInteractorSpy()
        var first: UIViewController? = presenter.viewController
        weak var released = first
        first = nil
        XCTAssertNil(released)
        let replacement = presenter.viewController
        XCTAssertTrue(replacement is DevicesTableViewController)
        XCTAssertTrue(presenter.viewController === replacement)
    }
}
private final class DevicesInteractorSpy: DevicesInteractorInput {
    var fetches = 0
    func fetchDevices() { fetches += 1 }
}
