import Foundation
import RuuviCloud
import RuuviCore
import RuuviDaemon
import RuuviDFU
import RuuviLocal
import RuuviPersistence
import RuuviPool
import RuuviReactor
import RuuviRepository
import RuuviService
import RuuviStorage
import XCTest
@testable import station

final class UserFacingErrorTests: XCTestCase {
    func testNestedInfrastructureErrorsPreserveTheirOriginalExplanationForTheUser() {
        let reason = "Could not save sensor history: device storage is full."
        let error = NSError(domain: "Storage", code: 28, userInfo: [NSLocalizedDescriptionKey: reason])
        let persistence = RuuviPersistenceError.grdb(error)
        let pool = RuuviPoolError.ruuviPersistence(persistence)
        let storage = RuuviStorageError.ruuviPersistence(persistence)
        let reactor = RuuviReactorError.ruuviPersistence(persistence)
        let repository = RuuviRepositoryError.ruuviStorage(storage)
        let errors: [Error] = [
            RuuviLocalError.disk(error), persistence, pool, storage, reactor, repository,
            RuuviRepositoryError.ruuviPool(pool),
            RuuviDaemonError.ruuviPersistence(persistence), RuuviDaemonError.ruuviPool(pool),
            RuuviDaemonError.ruuviReactor(reactor), RuuviDaemonError.ruuviStorage(storage),
            RuuviServiceError.writeToDisk(error), RuuviServiceError.ruuviRepository(repository),
            RuuviServiceError.ruuviStorage(storage), RuuviServiceError.ruuviPool(pool),
            RuuviServiceError.ruuviLocal(.disk(error)), RuuviServiceError.ruuviCloud(.api(.networking(error))),
            RuuviServiceError.networking(error), RuuviCloudApiError.networking(error),
            RuuviCloudApiError.parsing(error),
            RUError.ruuviLocal(.disk(error)), RUError.ruuviPool(pool), RUError.ruuviPersistence(persistence),
            RUError.ruuviStorage(storage), RUError.ruuviService(.ruuviRepository(repository)),
            RUError.persistence(error), RUError.networking(error), RUError.parse(error), RUError.map(error),
            RUError.writeToDisk(error), RUError.dfuError(.init(description: reason)),
        ]
        for wrapped in errors { XCTAssertEqual(wrapped.localizedDescription, reason, String(describing: wrapped)) }
    }

    func testKnownApiFailuresHaveReadableMessagesAndBadParametersCanRemainSilent() throws {
        let codes: [RuuviCloudApiErrorCode] = [
            .erForbidden, .erUnauthorized, .erInternal, .erInvalidFormat, .erUserNotFound, .erSensorNotFound,
            .erTokenExpired, .erThrottled, .erGatewayNotFound, .erGatewayAlreadyWhitelisted,
            .erGatewayStatusReportFailed, .erConflict, .erSubscriptionNotFound, .erShareCountReached,
            .erClaimCountReached, .erSensorShareCountReached, .erNoDataToShare, .erSensorAlreadyShared,
            .erSensorAlreadyClaimed, .erSensorAlreadyRegistered, .erUnableToSendEmail, .erSubscriptionCodeExists,
            .erSubscriptionCodeUsed, .erMissingArgument, .erInvalidDensityMode, .erInvalidSortMode,
            .erInvalidTimeRange, .erOldEntry, .erInvalidEmailAddress, .erInvalidMacAddress,
            .erInvalidEnumValue, .erSubDataStorageError, .erSubNoUser, .ok,
        ]
        var messages = Set<String>()
        for code in codes {
            let text = try XCTUnwrap(RuuviCloudApiError.api(code).errorDescription)
            XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertNotEqual(text, code.rawValue)
            XCTAssertFalse(text.contains("%@"))
            XCTAssertFalse(text.contains("%s"))
            messages.insert(text)
        }
        XCTAssertGreaterThan(messages.count, 25, "Distinct server failures need distinct explanations")
        for error: RuuviCloudApiError in [
            .connection, .emptyResponse, .failedToGetDataFromResponse,
            .unexpectedHTTPStatusCode(500), .unexpectedHTTPStatusCodeShouldRetry(503),
        ] {
            XCTAssertFalse(try XCTUnwrap(error.errorDescription).isEmpty)
        }
        XCTAssertNil(RuuviCloudApiError.badParameters.errorDescription)
        XCTAssertNil(RuuviCloudError.api(.badParameters).errorDescription)
        XCTAssertNil(RuuviServiceError.ruuviCloud(.api(.badParameters)).errorDescription)
    }

    func testAppAndServiceErrorsExposeMessagesInsteadOfEnumNamesOrLocalizationKeys() throws {
        let core: [CoreError] = [
            .failedToGetDocumentsDirectory, .failedToGetPngRepresentation,
            .failedToGetCurrentLocation, .failedToGetDataFromResponse, .locationPermissionDenied,
            .locationPermissionNotDetermined, .objectNotFound, .objectInvalidated, .unableToSendEmail,
        ]
        let expected: [ExpectedError] = [
            .missingOpenWeatherMapAPIKey, .isAlreadySyncingLogsWithThisTag, .failedToDeleteTag,
        ]
        let unexpected: [UnexpectedError] = [
            .callbackErrorAndResultAreNil, .callerDeinitedDuringOperation,
            .failedToReverseGeocodeCoordinate, .failedToFindRuuviTag, .failedToFindLogsForTheTag,
            .viewModelUUIDIsNil, .failedToFindOrGenerateBackgroundImage, .bothLuidAndMacAreNil,
        ]
        var errors: [Error] =
            core.map { RUError.core($0) } + expected.map { RUError.expected($0) }
            + unexpected.map { RUError.unexpected($0) }
        errors += [
            RUError.bluetooth(.disconnected), RuuviCloudError.notAuthorized,
            RuuviCoreError.locationPermissionDenied, RuuviCoreError.locationPermissionNotDetermined,
            RuuviCoreError.failedToGetCurrentLocation, RuuviPersistenceError.failedToFindRuuviTag,
            RuuviLocalError.failedToGetJpegRepresentation, RuuviLocalError.failedToGetDocumentsDirectory,
        ]
        let services: [RuuviServiceError] = [
            .pictureUrlIsNil, .macIdIsNil, .bothLuidAndMacAreNil, .failedToParseNetworkResponse,
            .failedToFindOrGenerateBackgroundImage, .failedToGetJpegRepresentation, .isAlreadySyncingLogsWithThisTag,
        ]
        errors += services
        for error in errors {
            let text = error.localizedDescription
            XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertNotEqual(text, String(describing: error))
            XCTAssertFalse(text.contains("%@"))
            XCTAssertFalse(
                text.contains("The operation couldn’t be completed."), "Expected a specific explanation: \(error)")
        }
    }
}
