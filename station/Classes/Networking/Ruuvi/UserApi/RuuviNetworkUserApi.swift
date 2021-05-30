import Foundation
import Future
import BTKit
import UIKit
import RuuviOntology

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
protocol RuuviNetworkUserApi {
    func uploadImage(_ requestModel: UserApiSensorImageUploadRequest,
                     imageData: Data,
                     uploadProgress: ((Double) -> Void)?) -> Future<UserApiSensorImageUploadResponse, RUError>
}

protocol RuuviNetworkUserApiOutput: AnyObject {
    func uploadImageUpdateProgress(_ mac: MACIdentifier, percentage: Double)
}

extension RuuviNetworkUserApi {
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
