import Foundation
@testable import RuuviNotification
import XCTest

#if DEBUG || ALPHA
    final class AlertDebugLogTests: XCTestCase {
        // These contracts are unchanged from main f2c7357f7; preserve the user's existing log.
        private let entriesKey = "RuuviAlertDebugLog.entries"
        private var savedEntries: Any?
        private var savedEnabled = false

        override func setUp() {
            savedEnabled = RuuviAlertDebugLog.isEnabled
            savedEntries = UserDefaults.standard.object(forKey: entriesKey)
            RuuviAlertDebugLog.setEnabled(false)
            RuuviAlertDebugLog.clear()
            XCTAssertEqual(RuuviAlertDebugLog.text(), "")
        }

        override func tearDown() {
            RuuviAlertDebugLog.setEnabled(false)
            RuuviAlertDebugLog.clear()
            _ = RuuviAlertDebugLog.text()
            UserDefaults.standard.set(savedEntries, forKey: entriesKey)
            RuuviAlertDebugLog.setEnabled(savedEnabled)
        }

        func testDisabledLoggingDoesNotEvaluateMessagesOrEraseSavedEntries() {
            var evaluated = false
            func message() -> String { evaluated = true; return "Should not be evaluated" }
            RuuviAlertDebugLog.append("Disabled", message())
            XCTAssertFalse(evaluated)
            XCTAssertEqual(RuuviAlertDebugLog.text(), "")
            RuuviAlertDebugLog.setEnabled(true)
            RuuviAlertDebugLog.append("Sensor", "Office 🌿")
            let saved = RuuviAlertDebugLog.text()
            XCTAssertTrue(saved.hasSuffix("[Sensor] Office 🌿"))
            RuuviAlertDebugLog.setEnabled(false)
            RuuviAlertDebugLog.append("Disabled", message())
            XCTAssertFalse(evaluated)
            XCTAssertEqual(RuuviAlertDebugLog.text(), saved)
        }

        func testRetentionExportAndClearKeepTheLast600CompleteEntriesInOrder() throws {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ruuvi-alert-debug-log.txt")
            let previousFile = try? Data(contentsOf: url)
            defer {
                if let previousFile {
                    try? previousFile.write(to: url)
                } else {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            RuuviAlertDebugLog.setEnabled(true)
            for index in 0..<603 { RuuviAlertDebugLog.append("History", "Entry \(index)") }
            let text = RuuviAlertDebugLog.text()
            let lines = text.components(separatedBy: "\n")
            XCTAssertEqual(lines.count, 600)
            for (offset, line) in lines.enumerated() {
                XCTAssertTrue(line.hasSuffix("[History] Entry \(offset + 3)"))
                XCTAssertNotNil(
                    line.range(
                        of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} "#,
                        options: .regularExpression))
            }
            XCTAssertEqual(try RuuviAlertDebugLog.exportFileURL(), url)
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), text)
            RuuviAlertDebugLog.clear()
            XCTAssertEqual(RuuviAlertDebugLog.text(), "")
            XCTAssertTrue(RuuviAlertDebugLog.isEnabled)
        }

        func testConcurrentWritersRetainEveryWholeMessageWithoutDuplicates() {
            RuuviAlertDebugLog.setEnabled(true)
            DispatchQueue.concurrentPerform(iterations: 100) { index in
                RuuviAlertDebugLog.append("Concurrent", "Message \(index)")
            }
            let lines = RuuviAlertDebugLog.text().components(separatedBy: "\n")
            let messages = lines.compactMap { $0.components(separatedBy: "[Concurrent] ").last }
            XCTAssertEqual(lines.count, 100)
            XCTAssertEqual(Set(messages), Set((0..<100).map { "Message \($0)" }))
        }
    }
#endif
