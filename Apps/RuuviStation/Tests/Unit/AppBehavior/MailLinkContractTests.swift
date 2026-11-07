import XCTest
@testable import station

@MainActor final class MailLinkContractTests: XCTestCase {
    func testSubjectAndBodyRemainSingleQueryValuesWhenTheyContainSeparatorsUnicodeAndNewlines() throws {
        let presenter = MailComposerPresenterMessageUI()
        let errors = OffsetErrorSpy()
        presenter.errorPresenter = errors
        var opened = [URL]()
        var checked = [URL]()
        presenter.openURL = { opened.append($0) }
        presenter.canOpenURL = {
            checked.append($0); return true
        }
        let subject = "Sensor & calibration? #1 + 🌿"
        let body = "CO₂ & humidity=50%\nSecond line?body=unchanged"
        presenter.present(email: "support+ios@example.com", subject: subject, body: body)
        XCTAssertEqual(opened, checked)
        XCTAssertEqual(opened.count, 1)
        let parts = try XCTUnwrap(URLComponents(url: try XCTUnwrap(opened.first), resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.scheme, "mailto")
        XCTAssertEqual(parts.path, "support+ios@example.com")
        XCTAssertEqual(
            parts.queryItems, [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)])
        XCTAssertNil(parts.fragment)
        XCTAssertTrue(errors.errors.isEmpty)
    }

    func testMissingBodyStaysEmptyAndAnUnavailableMailAppShowsAnErrorWithoutOpeningAnything() throws {
        let presenter = MailComposerPresenterMessageUI()
        let errors = OffsetErrorSpy()
        presenter.errorPresenter = errors
        var opened = [URL]()
        presenter.openURL = { opened.append($0) }
        presenter.canOpenURL = { _ in true }
        presenter.present(email: "support@example.com", subject: "Feedback", body: nil)
        let parts = try XCTUnwrap(URLComponents(url: try XCTUnwrap(opened.first), resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.queryItems?.last, URLQueryItem(name: "body", value: ""))
        let direct = "mailto:support@example.com?subject=Feedback"
        presenter.present(email: direct)
        XCTAssertEqual(opened.last?.absoluteString, direct)
        presenter.canOpenURL = { _ in false }
        presenter.present(email: direct)
        presenter.present(email: "support@example.com", subject: "Feedback", body: nil)
        XCTAssertEqual(opened.count, 2)
        XCTAssertEqual(errors.errors.count, 2)
        XCTAssertTrue(errors.errors.allSatisfy { ($0 as? CoreError) == .unableToSendEmail })
    }
}
