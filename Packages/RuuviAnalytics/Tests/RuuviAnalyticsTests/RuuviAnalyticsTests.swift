@testable import RuuviAnalytics
import XCTest

final class RuuviAnalyticsTests: XCTestCase {
    func testAnalyticsProtocolsCanBeConsumedTogether() {
        let analytics = AnalyticsSpy()
        let reporter = ErrorReporterSpy()
        let sut = AnalyticsClient(
            analytics: analytics,
            reporter: reporter
        )
        let error = DummyError()

        sut.sync(consentAllowed: true, error: error)

        XCTAssertEqual(analytics.updates, 1)
        XCTAssertEqual(analytics.consentValues, [true])
        XCTAssertTrue(reporter.reportedErrors.first is DummyError)
    }
}

private struct AnalyticsClient {
    let analytics: RuuviAnalytics
    let reporter: RuuviErrorReporter

    func sync(consentAllowed: Bool, error: Error?) {
        analytics.setConsent(allowed: consentAllowed)
        analytics.update()
        if let error {
            reporter.report(error: error)
        }
    }
}

private final class AnalyticsSpy: RuuviAnalytics {
    var updates = 0
    var consentValues: [Bool] = []

    func update() {
        updates += 1
    }

    func setConsent(allowed: Bool) {
        consentValues.append(allowed)
    }
}

private final class ErrorReporterSpy: RuuviErrorReporter {
    var reportedErrors: [Error] = []

    func report(error: Error) {
        reportedErrors.append(error)
    }
}

private struct DummyError: Error {}
