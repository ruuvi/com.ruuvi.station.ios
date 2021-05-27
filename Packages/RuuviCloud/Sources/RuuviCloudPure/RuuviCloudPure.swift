import Foundation
import Future
import RuuviOntology

final class RuuviCloudPure: RuuviCloud {
    init(api: RuuviCloudApi, apiKey: String?) {
        self.api = api
        self.apiKey = apiKey
    }

    func requestCode(email: String) -> Future<String, RuuviCloudError> {
        let promise = Promise<String, RuuviCloudError>()
        let request = RuuviCloudApiRegisterRequest(email: email)
        api.register(request)
            .on(success: { response in
                promise.succeed(value: response.email)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func validateCode(code: String) -> Future<String, RuuviCloudError> {
        let promise = Promise<String, RuuviCloudError>()
        let request = RuuviCloudApiVerifyRequest(token: code)
        api.verify(request)
            .on(success: { [weak self] response in
                self?.apiKey = response.accessToken
                promise.succeed(value: response.accessToken)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func loadSensors() -> Future<[CloudSensor], RuuviCloudError> {
        let promise = Promise<[CloudSensor], RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        api.user(authorization: apiKey).on(success: { response in
            promise.succeed(value: response.sensors)
        }, failure: { error in
            promise.fail(error: .api(error))
        })
        return promise.future
    }

    private var apiKey: String?
    private let api: RuuviCloudApi
    private lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
}
