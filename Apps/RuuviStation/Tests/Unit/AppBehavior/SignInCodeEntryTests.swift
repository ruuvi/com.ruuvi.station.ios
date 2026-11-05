import UIKit
import XCTest
@testable import station

@MainActor final class SignInCodeEntryTests: XCTestCase {
    func testAutofillUppercasesRemovesSpacesAndClearsOldCharactersForShorterCode() {
        let view = RuuviCodeView()
        let delegate = CodeEntryDelegateSpy()
        view.delegate = delegate
        view.autofill(with: nil)
        XCTAssertEqual(delegate.finishes, 0)
        view.autofill(with: "b c 2 3")
        XCTAssertEqual(view.ruuviCode(), "BC23")
        XCTAssertTrue(view.isValidCode)
        XCTAssertEqual(delegate.finishes, 1)
        view.autofill(with: "d4")
        XCTAssertEqual(view.ruuviCode(), "D4")
        XCTAssertFalse(view.isValidCode)
        view.autofill(with: "")
        XCTAssertEqual(view.ruuviCode(), "")
        XCTAssertFalse(view.isValidCode)
        view.autofill(with: "ABCD")
        view.reset()
        XCTAssertEqual(view.ruuviCode(), "")
        XCTAssertFalse(view.isValidCode)
        XCTAssertEqual(view.arrangedSubviews.count, 4)
    }

    func testTypingAcceptsTheCodeAlphabetCaseInsensitivelyAndRejectsAmbiguousCharacters() throws {
        let view = RuuviCodeView()
        let field = try XCTUnwrap(view.arrangedSubviews.first as? RuuviCodeTextField)
        for char in "ABCDFGHJKLMNPQRSTVWXYZ23456789" {
            for value in [String(char), String(char).lowercased()] {
                field.text = ""
                XCTAssertFalse(
                    view.textField(
                        field, shouldChangeCharactersIn: .init(location: 0, length: 0), replacementString: value))
                XCTAssertEqual(field.text, String(char))
            }
        }
        for value in ["0", "1", "I", "O", "E", "U", "!", "😀", "é"] {
            field.text = ""
            XCTAssertFalse(
                view.textField(field, shouldChangeCharactersIn: .init(location: 0, length: 0), replacementString: value)
            )
            XCTAssertEqual(field.text, "")
        }
        XCTAssertTrue(
            view.textField(
                UITextField(), shouldChangeCharactersIn: .init(location: 0, length: 0), replacementString: "x"))
        XCTAssertFalse(
            view.textField(field, shouldChangeCharactersIn: .init(location: 0, length: 0), replacementString: ""))
        XCTAssertTrue(
            view.textField(field, shouldChangeCharactersIn: .init(location: 0, length: 1), replacementString: ""))
    }

    func testPastingAndSequentialTypingHonorFieldOrderAndValidation() throws {
        let view = RuuviCodeView()
        let fields = view.arrangedSubviews.compactMap { $0 as? RuuviCodeTextField }
        XCTAssertEqual(fields.count, 4)
        XCTAssertNil(fields[0].previousEntry)
        XCTAssertNil(fields[3].nextEntry)
        XCTAssertFalse(
            view.textField(fields[2], shouldChangeCharactersIn: .init(location: 0, length: 0), replacementString: "B"))
        XCTAssertEqual(fields[2].text, "")
        for (index, char) in "BCD2".enumerated() {
            XCTAssertFalse(
                view.textField(
                    fields[index], shouldChangeCharactersIn: .init(location: 0, length: 0),
                    replacementString: String(char)))
            view.textFieldDidBeginEditing(fields[index])
            view.textFieldDidEndEditing(fields[index])
        }
        XCTAssertEqual(view.ruuviCode(), "BCD2")
        XCTAssertTrue(view.isValidCode)
        XCTAssertFalse(
            view.textField(
                fields[0], shouldChangeCharactersIn: .init(location: 0, length: 0), replacementString: "gh45"))
        XCTAssertEqual(view.ruuviCode(), "GH45")
        XCTAssertTrue(view.isValidCode)
        fields[3].deleteBackward()
        XCTAssertEqual(view.ruuviCode(), "GH4")
        XCTAssertFalse(view.isValidCode)
        fields[3].deleteBackward()
        XCTAssertEqual(view.ruuviCode(), "GH")
    }

    func testTextFieldCursorAndBackspacePreservePreviousCharacterUntilCurrentIsEmpty() throws {
        let controller = UIViewController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let previous = RuuviCodeTextField(frame: CGRect(x: 10, y: 100, width: 44, height: 50))
        let current = RuuviCodeTextField(frame: CGRect(x: 60, y: 100, width: 44, height: 50))
        controller.view.addSubview(previous)
        controller.view.addSubview(current)
        current.previousEntry = previous
        previous.nextEntry = current
        previous.text = "B"
        current.text = "C"
        XCTAssertTrue(current.becomeFirstResponder())
        current.layoutIfNeeded()
        XCTAssertEqual(current.caretRect(for: current.beginningOfDocument), .zero)
        let cursor = try XCTUnwrap(current.subviews.first { $0.layer.animation(forKey: "blink") != nil })
        XCTAssertFalse(cursor.isHidden)
        XCTAssertEqual(cursor.frame.width, 22)
        current.deleteBackward()
        XCTAssertEqual(previous.text, "B")
        XCTAssertEqual(current.text, "")
        XCTAssertTrue(current.isFirstResponder)
        current.deleteBackward()
        XCTAssertEqual(previous.text, "")
        XCTAssertTrue(previous.isFirstResponder)
        XCTAssertTrue(cursor.isHidden)
        XCTAssertNil(cursor.layer.animation(forKey: "blink"))
        XCTAssertTrue(previous.resignFirstResponder())
    }
}

private final class CodeEntryDelegateSpy: NSObject, RuuviCodeViewDelegate {
    var finishes = 0
    func didFinishTypingCode() { finishes += 1 }
}
