import RuuviLocalization
import RuuviOntology
import SwiftUI
import XCTest
@testable import station

@MainActor final class VisibilityScreenContractTests: XCTestCase {
    func testHostedScreenForwardsTheExactEditSequenceAndPreservesItemsWhenDefaultSwitchChanges() async throws {
        let view = VisibilitySettingsViewController()
        let output = VisibilityScreenOutput()
        view.output = output
        let host = try AppViewHost(view)
        defer { host.close() }
        let hosted = try XCTUnwrap(view.children.first as? UIHostingController<VisibilitySettingsView>)
        let root = hosted.rootView
        let visible = VisibilitySettingsItemViewModel(variant: .init(type: .temperature), title: "Temperature")
        let hidden = VisibilitySettingsItemViewModel(variant: .init(type: .co2), title: "CO₂")
        view.display(
            viewModel: .init(
                descriptionText: "Choose measurements", useDefault: false,
                visibleItems: [visible], hiddenItems: [hidden], preview: nil))
        view.setSaving(true)
        XCTAssertTrue(root.state.isSaving)
        view.setUseDefaultSwitch(isOn: true)
        XCTAssertTrue(root.state.viewModel.useDefault)
        XCTAssertEqual(root.state.viewModel.visibleItems, [visible])
        XCTAssertEqual(root.state.viewModel.hiddenItems, [hidden])
        XCTAssertEqual(root.state.viewModel.descriptionText, "Choose measurements")
        view.setSaving(false)
        XCTAssertFalse(root.state.isSaving)
        root.onToggleUseDefault(false)
        root.onHideVisible(2)
        root.onShowHidden(3)
        root.onStartVisibleMove()
        root.onMoveVisible(4, 1)
        root.onFinishVisibleMove()
        view.backButtonDidTap()
        XCTAssertEqual(
            output.events, ["load", "default:false", "hide:2", "show:3", "start", "move:4:1", "finish", "back"])
    }

    func testNativeConfirmationKeepsCancelAndConfirmCallbacksSeparateAndShowsTheFailureMessage() async throws {
        let view = VisibilitySettingsViewController()
        let host = try AppViewHost(view)
        defer { host.close() }
        let actions = AlertActionRecorder()
        view.alertActions = actions.factory
        var confirmed = 0
        var cancelled = 0
        for choice in ["Cancel", "Hide"] {
            view.presentConfirmation(
                title: "Active alert", message: "Hide and disable its alert?",
                confirmTitle: "Hide", cancelTitle: "Cancel", onConfirm: { confirmed += 1 }, onCancel: { cancelled += 1 }
            )
            await waitForAppState("visibility confirmation shown") { view.presentedViewController is UIAlertController }
            let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.title, "Active alert")
            XCTAssertEqual(alert.message, "Hide and disable its alert?")
            XCTAssertEqual(alert.actions.map(\.title), ["Cancel", "Hide"])
            XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
            try actions.invoke(choice)
            XCTAssertEqual(confirmed, choice == "Hide" ? 1 : 0)
            XCTAssertEqual(cancelled, 1)
            await withCheckedContinuation { continuation in view.dismiss(animated: false) { continuation.resume() } }
        }
        view.showMessage("Could not save measurements")
        await waitForAppState("visibility error shown") { view.presentedViewController is UIAlertController }
        let error = try XCTUnwrap(view.presentedViewController as? UIAlertController)
        XCTAssertNil(error.title)
        XCTAssertEqual(error.message, "Could not save measurements")
        XCTAssertEqual(error.actions.map(\.title), [RuuviLocalization.ok])
    }
}

private final class VisibilityScreenOutput: VisibilitySettingsViewOutput {
    var events = [String]()
    func viewDidLoad() { events.append("load") }
    func viewDidAskToDismiss() { events.append("back") }
    func viewWillDisappear() { events.append("disappear") }
    func viewDidToggleUseDefault(isOn: Bool) { events.append("default:\(isOn)") }
    func viewDidRequestHideItem(at index: Int) { events.append("hide:\(index)") }
    func viewDidRequestShowItem(at index: Int) { events.append("show:\(index)") }
    func viewDidStartReorderingVisibleItems() { events.append("start") }
    func viewDidMoveVisibleItem(from sourceIndex: Int, to destinationIndex: Int) {
        events.append("move:\(sourceIndex):\(destinationIndex)")
    }
    func viewDidFinishReorderingVisibleItems() { events.append("finish") }
}
