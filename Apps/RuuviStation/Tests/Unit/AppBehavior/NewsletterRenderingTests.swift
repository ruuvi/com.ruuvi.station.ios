import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class NewsletterRenderingTests: XCTestCase {
    func testNewsletterExplainsTheActionAndFitsNarrowAndWideMenuFooters() throws {
        let view = MenuNewsletterView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let button = try XCTUnwrap(view.allDescendants.compactMap { $0 as? UIButton }.first)
        let labels = view.allDescendants.compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(labels.contains(RuuviLocalization.newsletterCardTitle))
        XCTAssertTrue(labels.contains(RuuviLocalization.newsletterCardDescription))
        XCTAssertEqual(button.title(for: .normal), RuuviLocalization.newsletterSubscribe)
        for width in [320.0, 430.0, 768.0] {
            view.frame.size.width = width
            view.setNeedsLayout(); view.layoutIfNeeded()
            let buttonFrame = button.convert(button.bounds, to: view)
            XCTAssertGreaterThanOrEqual(buttonFrame.minX, 20)
            XCTAssertLessThanOrEqual(buttonFrame.maxX, width - 20)
            XCTAssertGreaterThanOrEqual(buttonFrame.height, 44)
            XCTAssertLessThanOrEqual(buttonFrame.width, 232.01)
            XCTAssertEqual(button.layer.cornerRadius, button.bounds.height / 2)
            XCTAssertFalse(button.hasAmbiguousLayout)
            XCTAssertTrue(view.allDescendants.compactMap { $0 as? UIImageView }.contains { $0.image != nil })
        }
        var subscriptions = 0
        view.onSubscribe = { subscriptions += 1 }
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(subscriptions, 1)
        view.onSubscribe = nil
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(subscriptions, 1)
    }
}
