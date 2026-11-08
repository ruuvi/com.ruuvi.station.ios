@testable import station
import RuuviLocalization
import UIKit
import XCTest

/// The iPhone Duo gates must never fire on regular iPhones and iPads: that is what keeps their look
/// and behaviour unchanged. On the iPhone Duo simulator (where they are supposed to fire) the tests
/// are skipped.
@MainActor
final class RuuviDuoLayoutGateTests: XCTestCase {
    private var window: UIWindow?

    override func setUp() async throws {
        try await super.setUp()
        try XCTSkipIf(RuuviDuoLayout.isFoldableDevice, "Running on a device with a hinge (iPhone Duo).")
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testDuoGatesAreOffOutsideIPhoneDuo() throws {
        let controller = try makeControllerInWindow()

        XCTAssertFalse(RuuviDuoLayout.isVerticalBarActive(controller.traitCollection))
        XCTAssertFalse(RuuviDuoLayout.isFoldingDisplay(controller.view))
        XCTAssertTrue(RuuviDuoLayout.activeFolds(in: controller.view).isEmpty)
    }

    func testDuoGatesAreOffForViewsOutsideAWindow() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertFalse(RuuviDuoLayout.isFoldingDisplay(view))
        XCTAssertTrue(RuuviDuoLayout.activeFolds(in: view).isEmpty)
    }

    func testHingeGateIsOffAndOrientationLocksAreKept() {
        XCTAssertFalse(RuuviDuoLayout.isFoldableDevice)
        XCTAssertFalse(AppUtility.isFoldableDevice)
        XCTAssertEqual(AppUtility.supportedOrientations(lock: .portrait), .portrait)
        XCTAssertEqual(AppUtility.supportedOrientations(lock: .allButUpsideDown), .allButUpsideDown)
        XCTAssertEqual(AppUtility.supportedOrientations(lock: .all), .all)
    }

    func testVerticalBarConstraintSwitchKeepsTheOriginalConstraints() throws {
        let controller = try makeControllerInWindow()
        let child = UIView()
        child.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(child)
        let standard = [child.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor)]
        let verticalBar = [
            child.leadingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.leadingAnchor),
        ]

        let constraintSwitch = RuuviVerticalBarConstraintSwitch(standard: standard, verticalBar: verticalBar)

        XCTAssertTrue(standard.allSatisfy(\.isActive))
        XCTAssertFalse(verticalBar.contains(where: \.isActive))
        XCTAssertFalse(constraintSwitch.update(for: controller.traitCollection))
        XCTAssertFalse(constraintSwitch.isVerticalBarApplied)
        XCTAssertTrue(standard.allSatisfy(\.isActive))
        XCTAssertFalse(verticalBar.contains(where: \.isActive))
    }

    func testAppGeometryMatchesTheMainScreen() throws {
        let controller = try makeControllerInWindow()
        let mainScreen = UIScreen.main

        XCTAssertTrue(RuuviAppGeometry.screen(for: controller.view) === mainScreen)
        XCTAssertTrue(RuuviAppGeometry.screen(for: nil) === mainScreen)
        XCTAssertEqual(RuuviAppGeometry.bounds(for: controller.view), mainScreen.bounds)
        XCTAssertEqual(RuuviAppGeometry.bounds(for: nil), mainScreen.bounds)
        XCTAssertEqual(RuuviAppGeometry.scale(for: controller.view), mainScreen.scale)
        XCTAssertEqual(
            RuuviAppGeometry.screenTraits(for: controller.view).horizontalSizeClass,
            mainScreen.traitCollection.horizontalSizeClass
        )
        XCTAssertEqual(
            RuuviAppGeometry.screenTraits(for: controller.view).verticalSizeClass,
            mainScreen.traitCollection.verticalSizeClass
        )
    }

    private func makeControllerInWindow() throws -> UIViewController {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        self.window = window
        return controller
    }
}
