#if canImport(RuuviCloudApi)
import RuuviCloudApi
#endif
import RuuviCloud
import Foundation
import Future
import RuuviOntology
import RuuviPool
import XCTest

final class ImageAPIStub: RuuviCloudApi {
    let uploadResult = Promise<RuuviCloudApiSensorImageUploadResponse, RuuviCloudApiError>()
    var uploads: [(request: RuuviCloudApiSensorImageUploadRequest, data: Data)] = []
    var resetCalls = 0
    let sensorsResult = Promise<RuuviCloudApiGetSensorsDenseResponse, RuuviCloudApiError>()

    func uploadImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        imageData: Data,
        authorization _: String,
        uploadProgress _: ((Double) -> Void)?
    ) -> Future<RuuviCloudApiSensorImageUploadResponse, RuuviCloudApiError> {
        uploads.append((requestModel, imageData))
        return uploadResult.future
    }

    func resetImage(
        _ _: RuuviCloudApiSensorImageUploadRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiSensorImageResetResponse, RuuviCloudApiError> {
        resetCalls += 1
        XCTFail("No reset should be sent")
        let result = Promise<RuuviCloudApiSensorImageResetResponse, RuuviCloudApiError>()
        result.fail(error: .connection)
        return result.future
    }

    func register(
        _ _: RuuviCloudApiRegisterRequest
    ) -> Future<RuuviCloudApiRegisterResponse, RuuviCloudApiError> {
        fatalError("Unexpected register")
    }

    func verify(
        _ _: RuuviCloudApiVerifyRequest
    ) -> Future<RuuviCloudApiVerifyResponse, RuuviCloudApiError> {
        fatalError("Unexpected verify")
    }

    func deleteAccount(
        _ _: RuuviCloudApiAccountDeleteRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiAccountDeleteResponse, RuuviCloudApiError> {
        fatalError("Unexpected deleteAccount")
    }

    func registerPNToken(
        _ _: RuuviCloudPNTokenRegisterRequest,
        authorization _: String
    ) -> Future<RuuviCloudPNTokenRegisterResponse, RuuviCloudApiError> {
        fatalError("Unexpected registerPNToken")
    }

    func unregisterPNToken(
        _ _: RuuviCloudPNTokenUnregisterRequest,
        authorization _: String?
    ) -> Future<RuuviCloudPNTokenUnregisterResponse, RuuviCloudApiError> {
        fatalError("Unexpected unregisterPNToken")
    }

    func listPNTokens(
        _ _: RuuviCloudPNTokenListRequest,
        authorization _: String
    ) -> Future<RuuviCloudPNTokenListResponse, RuuviCloudApiError> {
        fatalError("Unexpected listPNTokens")
    }

    func claim(
        _ _: RuuviCloudApiClaimRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiClaimResponse, RuuviCloudApiError> {
        fatalError("Unexpected claim")
    }

    func contest(
        _ _: RuuviCloudApiContestRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiContestResponse, RuuviCloudApiError> {
        fatalError("Unexpected contest")
    }

    func unclaim(
        _ _: RuuviCloudApiUnclaimRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiUnclaimResponse, RuuviCloudApiError> {
        fatalError("Unexpected unclaim")
    }

    func share(
        _ _: RuuviCloudApiShareRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiShareResponse, RuuviCloudApiError> {
        fatalError("Unexpected share")
    }

    func unshare(
        _ _: RuuviCloudApiShareRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiUnshareResponse, RuuviCloudApiError> {
        fatalError("Unexpected unshare")
    }

    func sensors(
        _ _: RuuviCloudApiGetSensorsRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiGetSensorsResponse, RuuviCloudApiError> {
        fatalError("Unexpected sensors")
    }

    func owner(
        _ _: RuuviCloudApiGetSensorsRequest,
        authorization _: String
    ) -> Future<RuuviCloudAPICheckOwnerResponse, RuuviCloudApiError> {
        fatalError("Unexpected owner")
    }

    func sensorsDense(
        _ _: RuuviCloudApiGetSensorsDenseRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiGetSensorsDenseResponse, RuuviCloudApiError> {
        sensorsResult.future
    }

    func user(
        authorization _: String
    ) -> Future<RuuviCloudApiUserResponse, RuuviCloudApiError> {
        fatalError("Unexpected user")
    }

    func getSensorData(
        _ _: RuuviCloudApiGetSensorRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiGetSensorResponse, RuuviCloudApiError> {
        fatalError("Unexpected getSensorData")
    }

    func update(
        _ _: RuuviCloudApiSensorUpdateRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiSensorUpdateResponse, RuuviCloudApiError> {
        fatalError("Unexpected update")
    }

    func getSettings(
        _ _: RuuviCloudApiGetSettingsRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiGetSettingsResponse, RuuviCloudApiError> {
        fatalError("Unexpected getSettings")
    }

    func postSetting(
        _ _: RuuviCloudApiPostSettingRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiPostSettingResponse, RuuviCloudApiError> {
        fatalError("Unexpected postSetting")
    }

    func getMarketingConsent(
        authorization _: String
    ) -> Future<RuuviCloudMarketingConsent, RuuviCloudApiError> {
        fatalError("Unexpected getMarketingConsent")
    }

    func setMarketingConsent(
        _ _: RuuviCloudApiSetMarketingConsentRequest,
        authorization _: String
    ) -> Future<RuuviCloudMarketingConsent, RuuviCloudApiError> {
        fatalError("Unexpected setMarketingConsent")
    }

    func postSensorSettings(
        _ _: RuuviCloudApiPostSensorSettingsRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiPostSensorSettingsResponse, RuuviCloudApiError> {
        fatalError("Unexpected postSensorSettings")
    }

    func postAlert(
        _ _: RuuviCloudApiPostAlertRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiPostAlertResponse, RuuviCloudApiError> {
        fatalError("Unexpected postAlert")
    }

    func getAlerts(
        _ _: RuuviCloudApiGetAlertsRequest,
        authorization _: String
    ) -> Future<RuuviCloudApiGetAlertsResponse, RuuviCloudApiError> {
        fatalError("Unexpected getAlerts")
    }
}

final class ImagePoolStub: RuuviPool {
    let persistence = Promise<Bool, RuuviPoolError>()
    var queued: [RuuviCloudQueuedRequest] = []

    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) -> Future<Bool, RuuviPoolError> {
        queued.append(request)
        return persistence.future
    }

    func create(_ _: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected create")
    }

    func update(_ _: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        Future(value: true)
    }

    func delete(_ _: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected delete")
    }

    func deleteSensorSettings(_ _: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteSensorSettings")
    }

    func create(_ _: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected create")
    }

    func createLast(_ _: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected createLast")
    }

    func updateLast(_ _: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected updateLast")
    }

    func deleteLast(_ _: String) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteLast")
    }

    func create(_ _: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected create")
    }

    func deleteAllRecords(_ _: String) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteAllRecords")
    }

    func deleteAllRecords(_ _: String, before _: Date) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteAllRecords")
    }

    func cleanupDBSpace() -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected cleanupDBSpace")
    }

    func updateOffsetCorrection(
        type _: OffsetCorrectionType,
        with _: Double?,
        of _: RuuviTagSensor,
        lastOriginalRecord _: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviPoolError> {
        fatalError("Unexpected updateOffsetCorrection")
    }

    func updateDisplaySettings(
        for _: RuuviTagSensor,
        displayOrder _: [String]?,
        defaultDisplayOrder _: Bool?,
        displayOrderLastUpdated _: Date?,
        defaultDisplayOrderLastUpdated _: Date?
    ) -> Future<SensorSettings, RuuviPoolError> {
        fatalError("Unexpected updateDisplaySettings")
    }

    func updateDescription(
        for _: RuuviTagSensor,
        description _: String?,
        descriptionLastUpdated _: Date?
    ) -> Future<SensorSettings, RuuviPoolError> {
        fatalError("Unexpected updateDescription")
    }

    func readSensorSettings(_ _: RuuviTagSensor) -> Future<SensorSettings?, RuuviPoolError> {
        fatalError("Unexpected readSensorSettings")
    }

    func deleteQueuedRequest(_ _: RuuviCloudQueuedRequest) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteQueuedRequest")
    }

    var acknowledgedImages: [(MACIdentifier, Date?)] = []
    func deleteQueuedImageUploads(for macId: MACIdentifier, through date: Date?) -> Future<Bool, RuuviPoolError> {
        acknowledgedImages.append((macId, date))
        queued.removeAll {
            $0.type == .uploadImage && $0.uniqueKey == macId.value + "-uploadImage"
                && (date == nil || ($0.requestDate ?? .distantPast) <= date!)
        }
        return Future(value: true)
    }

    func deleteQueuedRequests() -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteQueuedRequests")
    }

    func deleteUserSettings() -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteUserSettings")
    }

    func save(
        subscription _: CloudSensorSubscription
    ) -> Future<CloudSensorSubscription, RuuviPoolError> {
        fatalError("Unexpected save")
    }

    func readSensorSubscriptionSettings(
        _ _: RuuviTagSensor
    ) -> Future<CloudSensorSubscription?, RuuviPoolError> {
        fatalError("Unexpected readSensorSubscriptionSettings")
    }
}
