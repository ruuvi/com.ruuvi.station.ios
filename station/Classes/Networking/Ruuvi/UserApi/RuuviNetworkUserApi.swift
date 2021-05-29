import Foundation
import Future
import BTKit
import UIKit
import RuuviOntology

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
protocol RuuviNetworkUserApi {
    func claim(_ requestModel: UserApiClaimRequest) -> Future<UserApiClaimResponse, RUError>
    func unclaim(_ requestModel: UserApiClaimRequest) -> Future<UserApiUnclaimResponse, RUError>
    func share(_ requestModel: UserApiShareRequest) -> Future<UserApiShareResponse, RUError>
    func unshare(_ requestModel: UserApiShareRequest) -> Future<UserApiUnshareResponse, RUError>
    func shared(_ requestModel: UserApiSharedRequest) -> Future<UserApiSharedResponse, RUError>
    func update(_ requestModel: UserApiSensorUpdateRequest) -> Future<UserApiSensorUpdateResponse, RUError>
    func uploadImage(_ requestModel: UserApiSensorImageUploadRequest,
                     imageData: Data,
                     uploadProgress: ((Double) -> Void)?) -> Future<UserApiSensorImageUploadResponse, RUError>
}

protocol RuuviNetworkUserApiOutput: AnyObject {
    func uploadImageUpdateProgress(_ mac: MACIdentifier, percentage: Double)
}

extension RuuviNetworkUserApi {
    func unclaim(_ mac: String) -> Future<Bool, RUError> {
        let requestModel = UserApiClaimRequest(name: nil, sensor: mac)
        let promise = Promise<Bool, RUError>()
        unclaim(requestModel)
            .on(success: {_ in
                promise.succeed(value: true)
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    func unshare(_ mac: String, for user: String?) -> Future<Bool, RUError> {
        let requestModel = UserApiShareRequest(user: user, sensor: mac)
        let promise = Promise<Bool, RUError>()
        unshare(requestModel)
            .on(success: {_ in
                promise.succeed(value: true)
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    func upload(image: UIImage,
                for mac: MACIdentifier,
                with output: RuuviNetworkUserApiOutput) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        if let pngData = image.jpegData(compressionQuality: 1.0) {
            let requestModel = UserApiSensorImageUploadRequest(sensor: mac.mac, mimeType: .jpg)
            uploadImage(requestModel,
                        imageData: pngData,
                        uploadProgress: {(percentage) in
                            output.uploadImageUpdateProgress(mac, percentage: percentage)
                        }).on(success: { response in
                            promise.succeed(value: response.uploadURL)
                        }, failure: { error in
                            promise.fail(error: .networking(error))
                        })
        } else {
            promise.fail(error: .core(.failedToGetPngRepresentation))
        }
        return promise.future
    }
}
