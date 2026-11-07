import UIKit
import XCTest
@testable import station

@MainActor final class NumericSignAccessoryTests: XCTestCase {
    func testMinusAccessoryTogglesTheSignWithoutCorruptingDecimalInput() throws {
        let field = UITextField()
        field.addNumericAccessory()
        let toolbar = try XCTUnwrap(field.inputAccessoryView as? UIToolbar)
        let button = try XCTUnwrap(toolbar.items?.first { $0.action != nil })
        let action = try XCTUnwrap(button.action)
        XCTAssertTrue(button.target === field)
        for original in ["12.5", "12,5", "0", ""] {
            field.text = original
            UIApplication.shared.sendAction(action, to: button.target, from: button, for: nil)
            XCTAssertEqual(field.text, "-" + original)
            UIApplication.shared.sendAction(action, to: button.target, from: button, for: nil)
            XCTAssertEqual(field.text, original, "Repeated sign taps must not produce two minus signs")
        }
    }

    func testExistingASCIIAndUnicodeMinusSignsCanAllBeRemoved() {
        let field = UITextField()
        for prefix in ["-", "－", "−"] {
            field.text = prefix + "7.25"
            field.handleMinusTap()
            XCTAssertEqual(field.text, "7.25")
        }
    }
}
