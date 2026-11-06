import Foundation
import XCTest
@testable import station

final class AlertDecimalInputTests: XCTestCase {
    func testTypingPastingAndReplacingSignedDecimalsSupportsBothLocaleSeparators() {
        for separator in [".", ","] {
            let accepted = [
                "", "-", "12", "-12", separator, "-" + separator, "12" + separator,
                "-12" + separator + "50", "0" + separator + "01",
            ]
            for value in accepted {
                XCTAssertTrue(
                    AlertDecimalInput.allows(
                        text: "", range: .init(location: 0, length: 0),
                        replacement: value, decimalSeparator: separator), value)
            }
            for value in [
                "--1", "1-", "1-2", "1e2", "NaN", "∞", "1 2", "1" + separator + "234", "1" + separator + separator,
            ] {
                XCTAssertFalse(
                    AlertDecimalInput.allows(
                        text: "", range: .init(location: 0, length: 0),
                        replacement: value, decimalSeparator: separator), value)
            }
            XCTAssertTrue(
                AlertDecimalInput.allows(
                    text: "12" + separator + "34", range: .init(location: 3, length: 2),
                    replacement: "50", decimalSeparator: separator))
            XCTAssertTrue(
                AlertDecimalInput.allows(
                    text: "-12", range: .init(location: 0, length: 1),
                    replacement: "", decimalSeparator: separator))
        }
    }

    func testInvalidUtf16RangesCannotCrashOrAcceptAnEdit() {
        XCTAssertFalse(
            AlertDecimalInput.allows(
                text: "12", range: .init(location: 5, length: 0),
                replacement: "3", decimalSeparator: "."))
        XCTAssertFalse(
            AlertDecimalInput.allows(
                text: "😀", range: .init(location: 1, length: 0),
                replacement: "3", decimalSeparator: "."))
        XCTAssertFalse(
            AlertDecimalInput.allows(
                text: "12", range: .init(location: 0, length: 2),
                replacement: "3", decimalSeparator: ""))
    }
}
