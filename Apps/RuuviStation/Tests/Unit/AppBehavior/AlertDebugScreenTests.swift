import RuuviNotification
import UIKit
import XCTest
@testable import station

#if DEBUG || ALPHA
    @MainActor final class AlertDebugScreenTests: XCTestCase {
        func testLogViewerRefreshesExportsAndClearsWithoutChangingTheEnabledPreference() async throws {
            let saved = DebugLogState()
            defer { saved.restore() }
            let view = AlertDebugLogViewController()
            let host = try AppViewHost(view)
            defer { host.close() }
            let text = try XCTUnwrap(view.view.allDescendants.compactMap { $0 as? UITextView }.first)
            XCTAssertEqual(text.text, "No alert debug entries yet.")
            XCTAssertFalse(text.isEditable)
            await waitForAppState("debug log attached") { text.window != nil && text.bounds.height > 0 }
            RuuviAlertDebugLog.setEnabled(true)
            RuuviAlertDebugLog.append("Screen", "Kitchen 🌿 alert")
            let expected = RuuviAlertDebugLog.text()
            try activate(view.navigationItem.rightBarButtonItems?.last)
            XCTAssertEqual(text.text, expected)
            try activate(view.navigationItem.rightBarButtonItems?.first)
            await waitForAppState("debug log share sheet") { view.presentedViewController is UIActivityViewController }
            XCTAssertEqual(try String(contentsOf: saved.url, encoding: .utf8), expected)
            await withCheckedContinuation { done in view.dismiss(animated: false) { done.resume() } }
            try activate(view.navigationItem.leftBarButtonItem)
            XCTAssertEqual(text.text, "Cleared. New entries will appear after the next alert event.")
            XCTAssertEqual(RuuviAlertDebugLog.text(), "")
            XCTAssertTrue(RuuviAlertDebugLog.isEnabled)
            try activate(view.navigationItem.rightBarButtonItems?.last)
            XCTAssertEqual(text.text, "No alert debug entries yet.")
        }

        func testRefreshScrollsToTheLastEntryWhenSensorNamesContainEmoji() async throws {
            let saved = DebugLogState()
            defer { saved.restore() }
            let view = AlertDebugLogViewController()
            let host = try AppViewHost(view)
            defer { host.close() }
            let text = try XCTUnwrap(view.view.allDescendants.compactMap { $0 as? UITextView }.first)
            await waitForAppState("debug log attached") { text.window != nil && text.bounds.height > 0 }
            RuuviAlertDebugLog.setEnabled(true)
            for index in 0..<100 {
                RuuviAlertDebugLog.append("Room", String(repeating: "🧑🏽‍🔬", count: 25) + " Entry \(index)")
            }
            _ = RuuviAlertDebugLog.text()
            try activate(view.navigationItem.rightBarButtonItems?.last)
            text.layoutIfNeeded()
            await flushAppBindings()
            XCTAssertTrue(text.text.hasSuffix("Entry 99"))
            let end = text.caretRect(for: text.endOfDocument)
            XCTAssertLessThanOrEqual(
                end.maxY, text.bounds.maxY + text.textContainerInset.bottom + 5,
                "Refresh must reveal the latest complete entry, using UTF-16 offsets for UIKit")
        }

        private func activate(_ item: UIBarButtonItem?) throws {
            let item = try XCTUnwrap(item)
            let action = try XCTUnwrap(item.action)
            XCTAssertTrue(UIApplication.shared.sendAction(action, to: item.target, from: item, for: nil))
        }
    }

    private final class DebugLogState {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ruuvi-alert-debug-log.txt")
        private let entries = UserDefaults.standard.object(forKey: "RuuviAlertDebugLog.entries")
        private let enabled = RuuviAlertDebugLog.isEnabled
        private var file: Data?
        init() {
            file = try? Data(contentsOf: url)
            RuuviAlertDebugLog.setEnabled(false)
            RuuviAlertDebugLog.clear()
            _ = RuuviAlertDebugLog.text()
        }
        func restore() {
            RuuviAlertDebugLog.setEnabled(false)
            RuuviAlertDebugLog.clear()
            _ = RuuviAlertDebugLog.text()
            UserDefaults.standard.set(entries, forKey: "RuuviAlertDebugLog.entries")
            RuuviAlertDebugLog.setEnabled(enabled)
            if let file { try? file.write(to: url) } else { try? FileManager.default.removeItem(at: url) }
        }
    }
#endif
