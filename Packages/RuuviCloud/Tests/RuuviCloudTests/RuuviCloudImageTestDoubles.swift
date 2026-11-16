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
        authorization: String,
        uploadProgress: ((Double) -> Void)?
    ) -> Future<RuuviCloudApiSensorImageUploadResponse, RuuviCloudApiError> {
        uploads.append((requestModel, imageData))
        return uploadResult.future
    }

    func resetImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSensorImageResetResponse, RuuviCloudApiError> {
        resetCalls += 1
        XCTFail("No reset should be sent")
        let result = Promise<RuuviCloudApiSensorImageResetResponse, RuuviCloudApiError>()
        result.fail(error: .connection)
        return result.future
    }

    func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) -> Future<RuuviCloudApiRegisterResponse, RuuviCloudApiError> {
        fatalError("Unexpected register")
    }

    func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) -> Future<RuuviCloudApiVerifyResponse, RuuviCloudApiError> {
        fatalError("Unexpected verify")
    }

    func deleteAccount(
        _ requestModel: RuuviCloudApiAccountDeleteRequest,
        authorization: String
    ) -> Future<RuuviCloudApiAccountDeleteResponse, RuuviCloudApiError> {
        fatalError("Unexpected deleteAccount")
    }

    func registerPNToken(
        _ requestModel: RuuviCloudPNTokenRegisterRequest,
        authorization: String
    ) -> Future<RuuviCloudPNTokenRegisterResponse, RuuviCloudApiError> {
        fatalError("Unexpected registerPNToken")
    }

    func unregisterPNToken(
        _ requestModel: RuuviCloudPNTokenUnregisterRequest,
        authorization: String?
    ) -> Future<RuuviCloudPNTokenUnregisterResponse, RuuviCloudApiError> {
        fatalError("Unexpected unregisterPNToken")
    }

    func listPNTokens(
        _ requestModel: RuuviCloudPNTokenListRequest,
        authorization: String
    ) -> Future<RuuviCloudPNTokenListResponse, RuuviCloudApiError> {
        fatalError("Unexpected listPNTokens")
    }

    func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiClaimResponse, RuuviCloudApiError> {
        fatalError("Unexpected claim")
    }

    func contest(
        _ requestModel: RuuviCloudApiContestRequest,
        authorization: String
    ) -> Future<RuuviCloudApiContestResponse, RuuviCloudApiError> {
        fatalError("Unexpected contest")
    }

    func unclaim(
        _ requestModel: RuuviCloudApiUnclaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnclaimResponse, RuuviCloudApiError> {
        fatalError("Unexpected unclaim")
    }

    func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiShareResponse, RuuviCloudApiError> {
        fatalError("Unexpected share")
    }

    func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnshareResponse, RuuviCloudApiError> {
        fatalError("Unexpected unshare")
    }

    func sensors(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorsResponse, RuuviCloudApiError> {
        fatalError("Unexpected sensors")
    }

    func owner(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) -> Future<RuuviCloudAPICheckOwnerResponse, RuuviCloudApiError> {
        fatalError("Unexpected owner")
    }

    func sensorsDense(
        _ requestModel: RuuviCloudApiGetSensorsDenseRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorsDenseResponse, RuuviCloudApiError> {
        sensorsResult.future
    }

    func user(
        authorization: String
    ) -> Future<RuuviCloudApiUserResponse, RuuviCloudApiError> {
        fatalError("Unexpected user")
    }

    func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorResponse, RuuviCloudApiError> {
        fatalError("Unexpected getSensorData")
    }

    func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSensorUpdateResponse, RuuviCloudApiError> {
        fatalError("Unexpected update")
    }

    func getSettings(
        _ requestModel: RuuviCloudApiGetSettingsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSettingsResponse, RuuviCloudApiError> {
        fatalError("Unexpected getSettings")
    }

    func postSetting(
        _ requestModel: RuuviCloudApiPostSettingRequest,
        authorization: String
    ) -> Future<RuuviCloudApiPostSettingResponse, RuuviCloudApiError> {
        fatalError("Unexpected postSetting")
    }

    func getMarketingConsent(
        authorization: String
    ) -> Future<RuuviCloudMarketingConsent, RuuviCloudApiError> {
        fatalError("Unexpected getMarketingConsent")
    }

    func setMarketingConsent(
        _ requestModel: RuuviCloudApiSetMarketingConsentRequest,
        authorization: String
    ) -> Future<RuuviCloudMarketingConsent, RuuviCloudApiError> {
        fatalError("Unexpected setMarketingConsent")
    }

    func postSensorSettings(
        _ requestModel: RuuviCloudApiPostSensorSettingsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiPostSensorSettingsResponse, RuuviCloudApiError> {
        fatalError("Unexpected postSensorSettings")
    }

    func postAlert(
        _ requestModel: RuuviCloudApiPostAlertRequest,
        authorization: String
    ) -> Future<RuuviCloudApiPostAlertResponse, RuuviCloudApiError> {
        fatalError("Unexpected postAlert")
    }

    func getAlerts(
        _ requestModel: RuuviCloudApiGetAlertsRequest,
        authorization: String
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

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected create")
    }

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        Future(value: true)
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected delete")
    }

    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteSensorSettings")
    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected create")
    }

    func createLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected createLast")
    }

    func updateLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected updateLast")
    }

    func deleteLast(_ ruuviTagId: String) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteLast")
    }

    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected create")
    }

    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteAllRecords")
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected deleteAllRecords")
    }

    func cleanupDBSpace() -> Future<Bool, RuuviPoolError> {
        fatalError("Unexpected cleanupDBSpace")
    }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviPoolError> {
        fatalError("Unexpected updateOffsetCorrection")
    }

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) -> Future<SensorSettings, RuuviPoolError> {
        fatalError("Unexpected updateDisplaySettings")
    }

    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) -> Future<SensorSettings, RuuviPoolError> {
        fatalError("Unexpected updateDescription")
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RuuviPoolError> {
        fatalError("Unexpected readSensorSettings")
    }

    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) -> Future<Bool, RuuviPoolError> {
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
        subscription: CloudSensorSubscription
    ) -> Future<CloudSensorSubscription, RuuviPoolError> {
        fatalError("Unexpected save")
    }

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) -> Future<CloudSensorSubscription?, RuuviPoolError> {
        fatalError("Unexpected readSensorSubscriptionSettings")
    }
}
