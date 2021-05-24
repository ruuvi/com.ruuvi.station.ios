import Foundation
import Future

extension RuuviNetworkUserApiURLSession {
    private enum Routes: String {
        case register
        case verify
        case claim
        case unclaim
        case share
        case unshare
        case shared
        case user
        case getSensorData = "get"
        case update
        case uploadImage = "upload"

        static let baseURL: URL = {
            guard let url = URL(string: "https://network.ruuvi.com") else {
                fatalError()
            }
            return url
        }()

        var url: URL {
            return Routes.baseURL.appendingPathComponent(self.rawValue)
        }
    }
}
final class RuuviNetworkUserApiURLSession: NSObject, RuuviNetworkUserApi {
    var keychainService: KeychainService!
    private lazy var uploadSession = URLSession(
        configuration: .default,
        delegate: self,
        delegateQueue: .main
    )
    private var progressHandlersByTaskID = [Int: ProgressHandler]()

    func register(_ requestModel: UserApiRegisterRequest) -> Future<UserApiRegisterResponse, RUError> {
        return request(endpoint: Routes.register,
                       with: requestModel,
                       method: .post)
    }

    func verify(_ requestModel: UserApiVerifyRequest) -> Future<UserApiVerifyResponse, RUError> {
        return request(endpoint: Routes.verify,
                       with: requestModel)
    }

    func claim(_ requestModel: UserApiClaimRequest) -> Future<UserApiClaimResponse, RUError> {
        return request(endpoint: Routes.claim,
                       with: requestModel,
                       method: .post,
                       authorizationRequered: true)
    }

    func unclaim(_ requestModel: UserApiClaimRequest) -> Future<UserApiUnclaimResponse, RUError> {
        return request(endpoint: Routes.unclaim,
                       with: requestModel,
                       method: .post,
                       authorizationRequered: true)
    }

    func share(_ requestModel: UserApiShareRequest) -> Future<UserApiShareResponse, RUError> {
        return request(endpoint: Routes.share,
                       with: requestModel,
                       method: .post,
                       authorizationRequered: true)
    }

    func unshare(_ requestModel: UserApiShareRequest) -> Future<UserApiUnshareResponse, RUError> {
        return request(endpoint: Routes.unshare,
                       with: requestModel,
                       method: .post,
                       authorizationRequered: true)
    }

    func shared(_ requestModel: UserApiSharedRequest) -> Future<UserApiSharedResponse, RUError> {
        return request(endpoint: Routes.shared,
                       with: requestModel,
                       method: .get,
                       authorizationRequered: true)
    }

    func user() -> Future<UserApiUserResponse, RUError> {
        let requestModel = UserApiUserRequest()
        return request(endpoint: Routes.user,
                       with: requestModel,
                       authorizationRequered: true)
    }

    func getSensorData(_ requestModel: UserApiGetSensorRequest) -> Future<UserApiGetSensorResponse, RUError> {
        return request(endpoint: Routes.getSensorData,
                       with: requestModel,
                       method: .get,
                       authorizationRequered: true)
    }

    func update(_ requestModel: UserApiSensorUpdateRequest) -> Future<UserApiSensorUpdateResponse, RUError> {
        return request(endpoint: Routes.update,
                       with: requestModel,
                       method: .post,
                       authorizationRequered: true)
    }

    func uploadImage(_ requestModel: UserApiSensorImageUploadRequest,
                     imageData: Data) -> Future<UserApiSensorImageUploadResponse, RUError> {
        let promise = Promise<UserApiSensorImageUploadResponse, RUError>()
        request(endpoint: Routes.uploadImage,
                with: requestModel,
                method: .post,
                authorizationRequered: true)
            .on(success: { [weak self] (response: UserApiSensorImageUploadResponse) in
                let url = response.uploadURL
                self?.upload(url: url, with: imageData, mimeType: .jpg, progress: { percentage in
                    #if DEBUG
                    debugPrint(percentage)
                    #endif
                }, completion: { result in
                    switch result {
                    case .success:
                        promise.succeed(value: response)
                    case .failure(let error):
                        promise.fail(error: error)
                    }
                })
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }
}

// MARK: - Private
extension RuuviNetworkUserApiURLSession {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func request<Request: Encodable, Response: Decodable>(
        endpoint: Routes,
        with model: Request,
        method: HttpMethod = .get,
        authorizationRequered: Bool = false
    ) -> Future<Response, RUError> {
        let promise = Promise<Response, RUError>()
        var url: URL = endpoint.url
        if method == .get {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            urlComponents?.queryItems = try? URLQueryItemEncoder().encode(model)
            guard let urlFromComponents = urlComponents?.url else {
                fatalError()
            }
            url = urlFromComponents
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if method != .get {
            request.httpBody = try? JSONEncoder().encode(model)
        }
        if authorizationRequered {
            guard let apiKey = keychainService.ruuviUserApiKey else {
                promise.fail(error: .ruuviNetwork(.notAuthorized))
                return promise.future
            }
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let error = error {
                promise.fail(error: .networking(error))
            } else {
                if let data = data {
                    #if DEBUG
                    if let object = try? JSONSerialization.jsonObject(with: data, options: []),
                    let jsonData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                    let prettyPrintedString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue) {
                        debugPrint("📬 Response of request", dump(request), prettyPrintedString)
                    }
                    #endif
                    let decoder = JSONDecoder()
                    do {
                        let baseResponse = try decoder.decode(UserApiBaseResponse<Response>.self, from: data)
                        switch baseResponse.result {
                        case .success(let model):
                            promise.succeed(value: model)
                        case .failure(let userApiError):
                            promise.fail(error: userApiError)
                        }
                    } catch let error {
                        #if DEBUG
                        debugPrint("❌ Parsing Error", dump(error))
                        #endif
                        promise.fail(error: .parse(error))
                    }
                } else {
                    promise.fail(error: .unexpected(.failedToParseHttpResponse))
                }
            }
        }
        task.resume()
        return promise.future
    }
}

extension RuuviNetworkUserApiURLSession {
    typealias Percentage = Double
    typealias ProgressHandler = (Percentage) -> Void
    typealias CompletionHandler = (Result<Data, RUError>) -> Void

    private func upload(
        url: URL,
        with data: Data,
        mimeType: MimeType,
        method: HttpMethod = .put,
        progress: @escaping ProgressHandler,
        completion: @escaping CompletionHandler
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(mimeType.rawValue, forHTTPHeaderField: "Content-Type")
        let task = uploadSession.uploadTask(
            with: request,
            from: data,
            completionHandler: { data, response, error in
                if let error = error {
                    completion(.failure(.networking(error)))
                } else if (response as? HTTPURLResponse)?.statusCode != 200 {
                    completion(.failure(.core(.failedToGetDataFromResponse)))
                } else if let data = data {
                    completion(.success(data))
                } else {
                    completion(.failure(.core(.failedToGetDataFromResponse)))
                }
            }
        )
        progressHandlersByTaskID[task.taskIdentifier] = progress
        task.resume()
    }
}

extension RuuviNetworkUserApiURLSession: URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let handler = progressHandlersByTaskID[task.taskIdentifier]
        handler?(progress)
    }
}
