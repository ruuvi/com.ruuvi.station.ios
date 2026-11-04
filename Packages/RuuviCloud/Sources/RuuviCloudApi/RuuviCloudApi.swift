import BTKit
import Foundation
import RuuviCloud
import RuuviOntology

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
public protocol RuuviCloudApi {
    func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiRegisterResponse

    func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiVerifyResponse

    func deleteAccount(
        _ requestModel: RuuviCloudApiAccountDeleteRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiAccountDeleteResponse

    func registerPNToken(
        _ requestModel: RuuviCloudPNTokenRegisterRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudPNTokenRegisterResponse

    func unregisterPNToken(
        _ requestModel: RuuviCloudPNTokenUnregisterRequest,
        authorization: String?
    ) async throws(RuuviCloudApiError) -> RuuviCloudPNTokenUnregisterResponse

    func listPNTokens(
        _ requestModel: RuuviCloudPNTokenListRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudPNTokenListResponse

    func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiClaimResponse

    func contest(
        _ requestModel: RuuviCloudApiContestRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiContestResponse

    func unclaim(
        _ requestModel: RuuviCloudApiUnclaimRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiUnclaimResponse

    func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiShareResponse

    func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiUnshareResponse

    func sensors(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetSensorsResponse

    func owner(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudAPICheckOwnerResponse

    func sensorsDense(
        _ requestModel: RuuviCloudApiGetSensorsDenseRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetSensorsDenseResponse

    func user(
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiUserResponse

    func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetSensorResponse

    func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiSensorUpdateResponse

    func uploadImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        imageData: Data,
        authorization: String,
        uploadProgress: ((Double) -> Void)?
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiSensorImageUploadResponse

    func resetImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiSensorImageResetResponse

    func getSettings(
        _ requestModel: RuuviCloudApiGetSettingsRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetSettingsResponse

    func postSetting(
        _ requestModel: RuuviCloudApiPostSettingRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiPostSettingResponse

    func getMarketingConsent(
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudMarketingConsent

    func setMarketingConsent(
        _ requestModel: RuuviCloudApiSetMarketingConsentRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudMarketingConsent

    func postSensorSettings(
        _ requestModel: RuuviCloudApiPostSensorSettingsRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiPostSensorSettingsResponse

    func postAlert(
        _ requestModel: RuuviCloudApiPostAlertRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiPostAlertResponse

    func getAlerts(
        _ requestModel: RuuviCloudApiGetAlertsRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetAlertsResponse
}

public protocol RuuviCloudApiFactory {
    func create(baseUrl: URL) -> RuuviCloudApi
}
