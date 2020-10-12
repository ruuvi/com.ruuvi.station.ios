import Foundation
import Future

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
protocol RuuviNetworkUserApi: class {
    func register(_ request: UserApiRegisterRequest) -> Future<UserApiRegisterResponse, RUError>
    func verify(_ request: UserApiVerifyRequest) -> Future<UserApiVerifyResponse, RUError>
    func claim(_ request: UserApiClaimRequest) -> Future<UserApiClaimResponse, RUError>
    func share(_ request: UserApiShareRequest) -> Future<UserApiShareResponse, RUError>
    func user() -> Future<UserApiUserResponse, RUError>
    func getSensorData(_ request: UserApiGetSensorRequest) -> Future<UserApiGetSensorResponse, RUError>
    func update(_ request: UserApiSensorUpdateRequest) -> Future<UserApiSensorUpdateResponse, RUError>
    func uploadImage(_ request: UserApiSensorImageUploadRequest, imageData: Data) -> Future<UserApiSensorImageUploadResponse, RUError>
}
