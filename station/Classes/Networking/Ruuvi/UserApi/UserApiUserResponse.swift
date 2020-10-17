import Foundation
import Future

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
protocol RuuviNetworkUserApi: class {
    func register(_ requestModel: UserApiRegisterRequest) -> Future<UserApiRegisterResponse, RUError>
    func verify(_ requestModel: UserApiVerifyRequest) -> Future<UserApiVerifyResponse, RUError>
    func claim(_ requestModel: UserApiClaimRequest) -> Future<UserApiClaimResponse, RUError>
    func share(_ requestModel: UserApiShareRequest) -> Future<UserApiShareResponse, RUError>
    func user() -> Future<UserApiUserResponse, RUError>
    func getSensorData(_ requestModel: UserApiGetSensorRequest) -> Future<UserApiGetSensorResponse, RUError>
    func update(_ requestModel: UserApiSensorUpdateRequest) -> Future<UserApiSensorUpdateResponse, RUError>
    func uploadImage(_ requestModel: UserApiSensorImageUploadRequest,
                     imageData: Data) -> Future<UserApiSensorImageUploadResponse, RUError>
}
