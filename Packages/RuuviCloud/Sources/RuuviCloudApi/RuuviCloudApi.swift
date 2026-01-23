import BTKit
import Foundation
import RuuviOntology

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
public protocol RuuviCloudApi {
    func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) async throws -> RuuviCloudApiRegisterResponse

    func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) async throws -> RuuviCloudApiVerifyResponse

    func deleteAccount(
        _ requestModel: RuuviCloudApiAccountDeleteRequest,
        authorization: String
    ) async throws -> RuuviCloudApiAccountDeleteResponse

    func registerPNToken(
        _ requestModel: RuuviCloudPNTokenRegisterRequest,
        authorization: String
    ) async throws -> RuuviCloudPNTokenRegisterResponse

    func unregisterPNToken(
        _ requestModel: RuuviCloudPNTokenUnregisterRequest,
        authorization: String?
    ) async throws -> RuuviCloudPNTokenUnregisterResponse

    func listPNTokens(
        _ requestModel: RuuviCloudPNTokenListRequest,
        authorization: String
    ) async throws -> RuuviCloudPNTokenListResponse

    func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) async throws -> RuuviCloudApiClaimResponse

    func contest(
        _ requestModel: RuuviCloudApiContestRequest,
        authorization: String
    ) async throws -> RuuviCloudApiContestResponse

    func unclaim(
        _ requestModel: RuuviCloudApiUnclaimRequest,
        authorization: String
    ) async throws -> RuuviCloudApiUnclaimResponse

    func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) async throws -> RuuviCloudApiShareResponse

    func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) async throws -> RuuviCloudApiUnshareResponse

    func sensors(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorsResponse

    func owner(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) async throws -> RuuviCloudAPICheckOwnerResponse

    func sensorsDense(
        _ requestModel: RuuviCloudApiGetSensorsDenseRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorsDenseResponse

    func user(
        authorization: String
    ) async throws -> RuuviCloudApiUserResponse

    func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorResponse

    func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) async throws -> RuuviCloudApiSensorUpdateResponse

    func uploadImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        imageData: Data,
        authorization: String,
        uploadProgress: ((Double) -> Void)?
    ) async throws -> RuuviCloudApiSensorImageUploadResponse

    func resetImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        authorization: String
    ) async throws -> RuuviCloudApiSensorImageResetResponse

    func getSettings(
        _ requestModel: RuuviCloudApiGetSettingsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSettingsResponse

    func postSetting(
        _ requestModel: RuuviCloudApiPostSettingRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostSettingResponse

    func postSensorSettings(
        _ requestModel: RuuviCloudApiPostSensorSettingsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostSensorSettingsResponse

    func postAlert(
        _ requestModel: RuuviCloudApiPostAlertRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostAlertResponse

    func getAlerts(
        _ requestModel: RuuviCloudApiGetAlertsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetAlertsResponse
}

public protocol RuuviCloudApiFactory {
    func create(baseUrl: URL) -> RuuviCloudApi
}
