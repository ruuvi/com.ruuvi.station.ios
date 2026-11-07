import RuuviFirmware
import RuuviOntology
import UIKit
import XCTest
@testable import RuuviDiscover
@testable import station

@MainActor final class DiscoveryFirmwareContractTests: XCTestCase {
    func testLegacyUpgradeKeepsTheIdentifierVersionAndDismissalSafetyContract() async throws {
        let fixture = DiscoveryFixture()
        let module = DiscoveryFirmwareSpy()
        let host = try AppViewHost(fixture.view)
        defer { host.close(); fixture.cleanup() }
        var request: (String, String?)?
        fixture.presenter.makeFirmware = { id, version in
            request = (id, version); return module
        }
        let uuid = UUID().uuidString
        fixture.presenter.viewDidConfirmToUpdateFirmware(for: uuid)
        await waitForAppState("legacy firmware module presented") {
            module.viewController.presentingViewController != nil
        }
        XCTAssertEqual(request?.0, uuid)
        XCTAssertEqual(request?.1, "<=2.5.9")
        XCTAssertTrue(module.output === fixture.presenter)
        let presentation = try XCTUnwrap(module.viewController.presentationController)
        module.safeToDismiss = false
        XCTAssertEqual(presentation.delegate?.presentationControllerShouldDismiss?(presentation), false)
        module.safeToDismiss = true
        XCTAssertEqual(presentation.delegate?.presentationControllerShouldDismiss?(presentation), true)
        let unrelated = UIPresentationController(presentedViewController: UIViewController(), presenting: fixture.view)
        XCTAssertTrue(fixture.presenter.presentationControllerShouldDismiss(unrelated))
        fixture.presenter.ruuviFirmwareSuccessfullyUpgraded(module)
        await waitForAppState("successful firmware dismissed") { module.viewController.presentingViewController == nil }
    }

    func testNfcUpgradePreservesTheFirmwareLabelAndCannotDismissDuringAnUpdate() async throws {
        let fixture = DiscoveryFixture()
        let module = DiscoveryFirmwareSpy()
        let host = try AppViewHost(fixture.view)
        defer { host.close(); fixture.cleanup() }
        var request: (String, String?)?
        fixture.presenter.makeFirmware = { id, version in
            request = (id, version); return module
        }
        fixture.presenter.viewDidAskToUpgradeFirmware(of: nil)
        XCTAssertNil(request)
        let sensor = NFCSensor(id: UUID().uuidString, macId: "AA:BB:CC:DD:EE:FF", firmwareVersion: "3.31.1+0")
        fixture.presenter.viewDidAskToUpgradeFirmware(of: sensor)
        await waitForAppState("NFC firmware module presented") { module.viewController.presentingViewController != nil }
        XCTAssertEqual(request?.0, sensor.id)
        XCTAssertEqual(request?.1, "3.31.1")
        XCTAssertTrue(module.output === fixture.presenter)
        let presentation = try XCTUnwrap(module.viewController.presentationController)
        module.safeToDismiss = false
        XCTAssertEqual(presentation.delegate?.presentationControllerShouldDismiss?(presentation), false)
        module.safeToDismiss = true
        XCTAssertEqual(presentation.delegate?.presentationControllerShouldDismiss?(presentation), true)
    }

    func testCopyActionsPreserveTheExactNfcIdentifiers() throws {
        let fixture = DiscoveryFixture()
        XCTAssertTrue(fixture.presenter.pasteboard === UIPasteboard.general)
        let name = UIPasteboard.Name("DiscoveryFirmwareContractTests.\(UUID().uuidString)")
        let pasteboard = try XCTUnwrap(UIPasteboard(name: name, create: true))
        fixture.presenter.pasteboard = pasteboard
        defer { UIPasteboard.remove(withName: name); fixture.cleanup() }
        let sensor = NFCSensor(id: "secret-with-punctuation:+/==", macId: "AA:BB:CC:DD:EE:FF", firmwareVersion: "2.5.9")
        fixture.presenter.viewDidACopyMacAddress(of: sensor)
        XCTAssertEqual(pasteboard.string, sensor.macId)
        fixture.presenter.viewDidACopySecret(of: sensor)
        XCTAssertEqual(pasteboard.string, sensor.id)
        fixture.presenter.viewDidACopySecret(of: nil)
        XCTAssertNil(pasteboard.string)
        fixture.presenter.viewDidACopyMacAddress(of: nil)
        XCTAssertNil(pasteboard.string)
        XCTAssertTrue(fixture.ownership.additions.isEmpty)
    }
}

private final class DiscoveryFirmwareSpy: RuuviFirmware {
    let viewController = UIViewController()
    var router: AnyObject?
    weak var output: RuuviFirmwareOutput?
    var safeToDismiss = true
    func isSafeToDismiss() -> Bool { safeToDismiss }
}
