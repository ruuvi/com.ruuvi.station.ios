import Foundation
import Future
import BTKit
import RuuviOntology

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
protocol RuuviCloudApi {
    func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) -> Future<RuuviCloudApiRegisterResponse, RuuviCloudApiError>

    func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) -> Future<RuuviCloudApiVerifyResponse, RuuviCloudApiError>

    func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiClaimResponse, RuuviCloudApiError>

    func unclaim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnclaimResponse, RuuviCloudApiError>

    func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiShareResponse, RuuviCloudApiError>

    func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnshareResponse, RuuviCloudApiError>

    func sensors(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorsResponse, RuuviCloudApiError>

    func user(
        authorization: String
    ) -> Future<RuuviCloudApiUserResponse, RuuviCloudApiError>

    func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorResponse, RuuviCloudApiError>

    func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSensorUpdateResponse, RuuviCloudApiError>

    func uploadImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        imageData: Data,
        authorization: String,
        uploadProgress: ((Double) -> Void)?
    ) -> Future<RuuviCloudApiSensorImageUploadResponse, RuuviCloudApiError>

    func resetImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSensorImageResetResponse, RuuviCloudApiError>

    func getSettings(
        _ requestModel: RuuviCloudApiGetSettingsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSettingsResponse, RuuviCloudApiError>

    func postSetting(
        _ requestModel: RuuviCloudApiPostSettingRequest,
        authorization: String
    ) -> Future<RuuviCloudApiPostSettingResponse, RuuviCloudApiError>

    func postAlert(
        _ requestModel: RuuviCloudApiPostAlertRequest,
        authorization: String
    ) -> Future<RuuviCloudApiPostAlertResponse, RuuviCloudApiError>
}

protocol RuuviCloudApiFactory {
    func create(baseUrl: URL) -> RuuviCloudApi
}

public enum MimeType: String, Encodable {
    case png = "image/png"
    case gif = "image/gif"
    case jpg = "image/jpeg"
}
