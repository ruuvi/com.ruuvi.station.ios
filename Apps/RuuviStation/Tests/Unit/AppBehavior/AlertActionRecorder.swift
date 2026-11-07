import UIKit
import XCTest
@testable import station

@MainActor final class AlertActionRecorder {
    private struct Entry { let action: UIAlertAction; let handler: AlertActionFactory.Handler? }
    private var entries = [Entry]()
    var factory: AlertActionFactory {
        AlertActionFactory { [weak self] title, style, handler in
            let action = UIAlertAction(title: title, style: style, handler: handler)
            self?.entries.append(.init(action: action, handler: handler))
            return action
        }
    }
    func reset() { entries.removeAll() }
    func invoke(_ title: String) throws {
        let entry = try XCTUnwrap(entries.last { $0.action.title == title }, "Missing dialog action: " + title)
        XCTAssertTrue(entry.action.isEnabled, "Disabled actions must not be invoked")
        guard entry.action.isEnabled else { return }
        entry.handler?(entry.action)
    }
}
