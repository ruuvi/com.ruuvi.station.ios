import UIKit
import XCTest
@testable import station

@MainActor final class BottomSheetContractTests: XCTestCase {
    func testPlainSheetPreservesItsPresentationOptionsAndClampsContentHeight() async throws {
        let controller = UIViewController()
        let host = try AppViewHost(controller)
        defer { host.close() }
        let sheetContent = UIViewController()
        sheetContent.preferredContentSize = CGSize(width: 300, height: 600)
        let delegate = SheetDismissalSpy()
        let configuration = SheetConfiguration(
            maxHeight: 300, prefersGrabberVisible: false, preferredCornerRadius: 24,
            prefersScrollingExpandsWhenScrolledToEdge: true, prefersEdgeAttachedInCompactHeight: false)
        controller.presentDynamicBottomSheet(vc: sheetContent, configuration: configuration, delegate: delegate)
        await waitForAppState("custom sheet visible") { sheetContent.view.window != nil }
        let sheet = try XCTUnwrap(sheetContent.sheetPresentationController)
        XCTAssertEqual(sheetContent.modalPresentationStyle, .pageSheet)
        XCTAssertTrue(sheet.delegate === delegate)
        XCTAssertEqual(sheet.detents.count, 1)
        XCTAssertFalse(sheet.prefersGrabberVisible)
        XCTAssertEqual(sheet.preferredCornerRadius, 24)
        XCTAssertTrue(sheet.prefersScrollingExpandsWhenScrolledToEdge)
        XCTAssertFalse(sheet.prefersEdgeAttachedInCompactHeight)
        XCTAssertEqual(sheetContent.view.bounds.height - sheetContent.view.safeAreaInsets.bottom, 300, accuracy: 2)
        await dismiss(controller)
    }

    func testNavigationSheetIncludesNavigationChromeAndUsesTheDefaultOptions() async throws {
        let controller = UIViewController()
        let host = try AppViewHost(controller)
        defer { host.close() }
        let root = UIViewController()
        root.preferredContentSize = CGSize(width: 300, height: 180)
        controller.presentDynamicBottomSheetWithNav(vc: root)
        await waitForAppState("navigation sheet visible") { root.view.window != nil }
        let navigation = try XCTUnwrap(controller.presentedViewController as? UINavigationController)
        XCTAssertTrue(navigation.viewControllers.first === root)
        let sheet = try XCTUnwrap(navigation.sheetPresentationController)
        XCTAssertTrue(sheet.prefersGrabberVisible)
        XCTAssertEqual(sheet.preferredCornerRadius, 16)
        XCTAssertFalse(sheet.prefersScrollingExpandsWhenScrolledToEdge)
        XCTAssertTrue(sheet.prefersEdgeAttachedInCompactHeight)
        XCTAssertEqual(sheet.detents.count, 1)
        let expected = root.preferredContentSize.height + navigation.navigationBar.frame.height + 20
        XCTAssertEqual(navigation.view.bounds.height - navigation.view.safeAreaInsets.bottom, expected, accuracy: 2)
        await dismiss(controller)
    }

    func testDismissedSheetsReleaseTheirContentAndNavigationControllers() async throws {
        let controller = UIViewController()
        let host = try AppViewHost(controller)
        defer { host.close() }
        for withNavigation in [false, true] {
            var content: UIViewController? = UIViewController()
            content?.preferredContentSize = CGSize(width: 300, height: 200)
            weak var releasedContent = content
            if withNavigation {
                controller.presentDynamicBottomSheetWithNav(vc: try XCTUnwrap(content))
            } else {
                controller.presentDynamicBottomSheet(vc: try XCTUnwrap(content))
            }
            await waitForAppState("sheet visible") { content?.view.window != nil }
            weak var releasedPresentation = controller.presentedViewController
            await dismiss(controller)
            content = nil
            await flushAppBindings()
            XCTAssertNil(releasedContent)
            XCTAssertNil(releasedPresentation)
        }
    }

    private func dismiss(_ controller: UIViewController) async {
        await withCheckedContinuation { continuation in
            controller.dismiss(animated: false) { continuation.resume() }
        }
    }
}

private final class SheetDismissalSpy: NSObject, UIAdaptivePresentationControllerDelegate {}
