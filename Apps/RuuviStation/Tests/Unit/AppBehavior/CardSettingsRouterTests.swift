import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class CardSettingsRouterTests: XCTestCase {
    func testNotesRoutePreservesTheDraftAndConnectsSaveAcknowledgementToNavigation() async throws {
        let root = UIViewController()
        let host = try AppViewHost(root)
        defer { host.close() }
        await waitForAppState("settings route attached") {
            root.view.window != nil && root.navigationController === host.navigation
        }
        let router = CardsSettingsRouter()
        router.transitionHandler = root
        var notes = [String?]()
        var finish: ((Result<Void, Error>) -> Void)?
        router.openNotesSettings(notes: "Original 🌿") { value, done in
            notes.append(value); finish = done
        }
        let editor = try XCTUnwrap(host.navigation.topViewController as? NotesSettingsViewController)
        editor.loadViewIfNeeded()
        let text = try XCTUnwrap(editor.view.allDescendants.compactMap { $0 as? UITextView }.first)
        XCTAssertEqual(text.text, "Original 🌿")
        text.text = "Edited 🌿"
        let update = try XCTUnwrap(
            editor.view.allDescendants.compactMap { $0 as? UIButton }.first {
                $0.title(for: .normal) == RuuviLocalization.update
            })
        update.sendActions(for: .touchUpInside)
        XCTAssertEqual(notes.compactMap { $0 }, ["Edited 🌿"])
        XCTAssertTrue(host.navigation.topViewController === editor)
        finish?(.success(()))
        await waitForAppState("saved notes route closed") { host.navigation.topViewController === root }
    }

    func testLEDRouteForwardsTheSelectedBrightnessAndPreservesTheInitialCheckmark() async throws {
        let root = UIViewController()
        let host = try AppViewHost(root)
        defer { host.close() }
        await waitForAppState("settings route attached") {
            root.view.window != nil && root.navigationController === host.navigation
        }
        let router = CardsSettingsRouter()
        router.transitionHandler = root
        var levels = [RuuviLedBrightnessLevel]()
        var firmwareRequests = 0
        router.openLedBrightnessSettings(
            selection: .dim, firmwareVersion: "1.3.0", snapshotId: "sensor-A",
            onUpdateFirmware: { firmwareRequests += 1 }
        ) { level, done in
            levels.append(level); done(.success(()))
        }
        let supported = try XCTUnwrap(host.navigation.topViewController as? LEDBrightnessSettingsViewController)
        supported.loadViewIfNeeded()
        supported.view.layoutIfNeeded()
        let table = try XCTUnwrap(supported.view.allDescendants.compactMap { $0 as? UITableView }.first)
        table.layoutIfNeeded()
        XCTAssertEqual(table.cellForRow(at: IndexPath(row: 1, section: 0))?.accessoryType, .checkmark)
        supported.tableView(table, didSelectRowAt: IndexPath(row: 3, section: 0))
        await flushAppBindings()
        XCTAssertEqual(levels, [.bright])
    }

    func testUnsupportedLEDFirmwareRouteForwardsTheUpdateRequest() async throws {
        let root = UIViewController()
        let host = try AppViewHost(root)
        defer { host.close() }
        await waitForAppState("settings route attached") {
            root.view.window != nil && root.navigationController === host.navigation
        }
        let router = CardsSettingsRouter()
        router.transitionHandler = root
        var firmwareRequests = 0
        router.openLedBrightnessSettings(
            selection: .normal, firmwareVersion: "1.2.0", snapshotId: "sensor-A",
            onUpdateFirmware: { firmwareRequests += 1 }
        ) { _, _ in XCTFail("Unsupported firmware cannot accept writes") }
        let unsupported = try XCTUnwrap(host.navigation.topViewController as? LEDBrightnessSettingsViewController)
        unsupported.loadViewIfNeeded()
        let update = try XCTUnwrap(
            unsupported.view.allDescendants.compactMap { $0 as? UIButton }.first {
                $0.title(for: .normal) == RuuviLocalization.updateNow
            })
        update.sendActions(for: .touchUpInside)
        XCTAssertEqual(firmwareRequests, 1)
    }

    func testFirmwareRouteGuardsInteractiveDismissalUntilTheModuleIsSafe() async throws {
        let root = UIViewController()
        let host = try AppViewHost(root)
        let measurements = MeasurementFixture()
        defer { host.close(); measurements.cleanup() }
        await waitForAppState("settings route attached") {
            root.view.window != nil && root.navigationController === host.navigation
        }
        let router = CardsSettingsRouter()
        router.transitionHandler = root
        let module = SettingsFirmwareModuleSpy()
        var requested = [String]()
        router.makeFirmware = { sensor in
            requested.append(sensor.id); return module
        }
        XCTAssertTrue(
            router.presentationControllerShouldDismiss(
                UIPresentationController(presentedViewController: UIViewController(), presenting: root)))
        router.openUpdateFirmware(ruuviTag: measurements.sensor)
        await waitForAppState("firmware route presented") {
            root.presentedViewController === module.viewController && !module.viewController.isBeingPresented
        }
        XCTAssertEqual(requested, [measurements.sensor.id])
        XCTAssertTrue(module.output === router)
        let presentation = try XCTUnwrap(module.viewController.presentationController)
        XCTAssertTrue(presentation.delegate === router)
        XCTAssertFalse(router.presentationControllerShouldDismiss(presentation))
        module.safe = true
        XCTAssertTrue(router.presentationControllerShouldDismiss(presentation))
        module.output?.dfuModuleSuccessfullyUpgraded(module)
        await waitForAppState("firmware route dismissed") { root.presentedViewController == nil }
    }

    func testBackgroundRouteUsesTheSelectedSensorAndBackCompletionRunsOnce() async throws {
        let root = UIViewController()
        let host = try AppViewHost(root)
        let measurements = MeasurementFixture()
        defer { host.close(); measurements.cleanup() }
        await waitForAppState("settings route attached") {
            root.view.window != nil && root.navigationController === host.navigation
        }
        let router = CardsSettingsRouter()
        router.transitionHandler = root
        let background = SettingsBackgroundModuleSpy()
        var selected: String?
        router.makeBackgroundSelection = { sensor in
            selected = sensor.id; return background
        }
        router.openBackgroundSelectionView(ruuviTag: measurements.sensor)
        XCTAssertTrue(host.navigation.topViewController === background.viewController)
        XCTAssertEqual(selected, measurements.sensor.id)
        await waitForAppState("background route ready") {
            background.viewController.view.window != nil && host.navigation.transitionCoordinator == nil
        }
        await flushAppBindings()
        var completed = 0
        router.dismissToRoot { completed += 1 }
        XCTAssertEqual(completed, 1)
        await waitForAppState("background route closed") { host.navigation.topViewController === root }
    }
}

private final class SettingsFirmwareModuleSpy: DFUModuleInput {
    let viewController = UIViewController()
    weak var output: DFUModuleOutput?
    var safe = false
    func isSafeToDismiss() -> Bool { safe }
}
private final class SettingsBackgroundModuleSpy: BackgroundSelectionModuleInput {
    let viewController = UIViewController()
}
