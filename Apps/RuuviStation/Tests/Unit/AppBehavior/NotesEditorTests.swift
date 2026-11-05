import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class NotesEditorTests: XCTestCase {
    func testInitialNotesAndUnicodeEditsRespectTheCharacterLimit() throws {
        let fixture = try NotesEditorFixture(notes: "Room 🌡️")
        defer { fixture.host.close() }
        XCTAssertEqual(fixture.view.title, RuuviLocalization.notes)
        XCTAssertEqual(fixture.text.text, "Room 🌡️")
        XCTAssertTrue(fixture.text.isEditable)
        XCTAssertEqual(fixture.count.text, "6/1000")
        fixture.text.text = String(repeating: "🧑🏽‍🔬", count: 999)
        let end = NSRange(location: fixture.text.text.utf16.count, length: 0)
        XCTAssertTrue(fixture.view.textView(fixture.text, shouldChangeTextIn: end, replacementText: "a"))
        XCTAssertFalse(fixture.view.textView(fixture.text, shouldChangeTextIn: end, replacementText: "ab"))
        XCTAssertFalse(
            fixture.view.textView(
                fixture.text, shouldChangeTextIn: NSRange(location: 99999, length: 1), replacementText: "x"))
        fixture.text.text += "xy"
        fixture.view.textViewDidChange(fixture.text)
        XCTAssertEqual(fixture.text.text.count, 1000)
        XCTAssertTrue(fixture.text.text.hasSuffix("x"))
        XCTAssertEqual(fixture.count.text, "1000/1000")
        XCTAssertFalse(fixture.text.canPerformAction(NSSelectorFromString("share:"), withSender: nil))
    }

    func testSaveCoalescesRepeatedTapsAndReturnsOnlyAfterSuccessfulPersistence() async throws {
        let fixture = try NotesEditorFixture(notes: "Before")
        defer { fixture.host.close() }
        var saved = [String?]()
        var completion: ((Result<Void, Error>) -> Void)?
        fixture.view.onSave = { value, done in
            saved.append(value); completion = done
        }
        fixture.text.text = "  Updated notes\n"
        fixture.button.sendActions(for: .touchUpInside)
        fixture.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(saved.compactMap { $0 }, ["  Updated notes\n"])
        XCTAssertFalse(fixture.button.isEnabled)
        XCTAssertTrue(fixture.host.navigation.topViewController === fixture.view)
        completion?(.success(()))
        await waitForAppState("notes saved") { fixture.host.navigation.topViewController !== fixture.view }
        XCTAssertTrue(fixture.button.isEnabled)
    }

    func testSaveFailureKeepsTheDraftAndAllowsARetry() async throws {
        let fixture = try NotesEditorFixture(notes: "Before")
        defer { fixture.host.close() }
        var completions = [(Result<Void, Error>) -> Void]()
        fixture.view.onSave = { _, done in completions.append(done) }
        fixture.text.text = "Draft"
        fixture.button.sendActions(for: .touchUpInside)
        let error = NSError(
            domain: "NotesEditorTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not save notes"])
        completions[0](.failure(error))
        await waitForAppState("notes error") { fixture.view.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, "Could not save notes")
        XCTAssertEqual(alert.actions.map(\.style), [.cancel])
        XCTAssertEqual(fixture.text.text, "Draft")
        XCTAssertTrue(fixture.button.isEnabled)
        XCTAssertTrue(fixture.host.navigation.topViewController === fixture.view)
        await withCheckedContinuation { done in fixture.view.dismiss(animated: false) { done.resume() } }
        fixture.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(completions.count, 2)
        completions[1](.success(()))
        await waitForAppState("notes retry saved") { fixture.host.navigation.topViewController !== fixture.view }
    }

    func testClearingExistingNotesPersistsNilWhileEmptyToEmptyRequiresNoWrite() async throws {
        for initial in ["Existing note", "  \n"] {
            let fixture = try NotesEditorFixture(notes: initial)
            defer { fixture.host.close() }
            var saved = [String?]()
            fixture.view.onSave = { value, done in
                saved.append(value); done(.success(()))
            }
            fixture.text.text = " \n "
            fixture.button.sendActions(for: .touchUpInside)
            await waitForAppState("notes editor closed") { fixture.host.navigation.topViewController !== fixture.view }
            XCTAssertEqual(saved.count, initial == "Existing note" ? 1 : 0)
            XCTAssertTrue(saved.allSatisfy { $0 == nil })
        }
    }

    func testEditorWithoutSaveHandlerClosesAndEmptyNotesStartWithZeroCount() async throws {
        let fixture = try NotesEditorFixture(notes: nil)
        defer { fixture.host.close() }
        XCTAssertEqual(fixture.text.text, "")
        XCTAssertEqual(fixture.count.text, "0/1000")
        fixture.text.text = "New note"
        fixture.button.sendActions(for: .touchUpInside)
        await waitForAppState("editor without save handler closes") {
            fixture.host.navigation.topViewController !== fixture.view
        }
    }
}

@MainActor final class NotesEditorFixture {
    let view: NotesSettingsViewController
    let host: AppViewHost
    let text: UITextView
    let button: UIButton
    let count: UILabel
    init(notes: String?) throws {
        view = NotesSettingsViewController(notes: notes)
        host = try AppViewHost(view, withBackStack: true)
        text = try XCTUnwrap(view.view.allDescendants.compactMap { $0 as? UITextView }.first)
        button = try XCTUnwrap(
            view.view.allDescendants.compactMap { $0 as? UIButton }.first {
                $0.title(for: .normal) == RuuviLocalization.update
            })
        count = try XCTUnwrap(
            view.view.allDescendants.compactMap { $0 as? UILabel }.first { $0.text?.hasSuffix("/1000") == true })
    }
}
