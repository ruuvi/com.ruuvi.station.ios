import Foundation
import Future
import RuuviCloud

// swiftlint:disable file_length

extension RuuviCloudApiURLSession {
    private enum Routes: String {
        case register
        case verify
        case deleteAccount = "request-delete"
        case registerPNToken = "push-register"
        case unregisterPNToken = "push-unregister"
        case PNTokens = "push-list"
        case claim
        case unclaim
        case share
        case unshare
        case user
        case getSensorData = "get"
        case update
        case uploadImage = "upload"
        case settings
        case sensors
        case sensorsDense = "sensors-dense"
        case alerts
        case check
    }
}

public final class RuuviCloudApiURLSession: NSObject, RuuviCloudApi {
    private lazy var uploadSession: URLSession = {
        let config = URLSessionConfiguration.default
        if #available(iOS 11.0, *) {
            config.waitsForConnectivity = true
        }
        return URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: .main
        )
    }()
    private var progressHandlersByTaskID = [Int: ProgressHandler]()
    private let baseUrl: URL

    public init(baseUrl: URL) {
        self.baseUrl = baseUrl
        Reachability.start()
    }

    public func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) -> Future<RuuviCloudApiRegisterResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.register,
                       with: requestModel,
                       method: .post)
    }

    public func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) -> Future<RuuviCloudApiVerifyResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.verify,
                       with: requestModel)
    }

    public func deleteAccount(_ requestModel: RuuviCloudApiAccountDeleteRequest,
                              authorization: String) ->
    Future<RuuviCloudApiAccountDeleteResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.deleteAccount,
                       with: requestModel,
                       method: .post,
                       authorization: authorization)
    }

    public func registerPNToken(
        _ requestModel: RuuviCloudPNTokenRegisterRequest,
        authorization: String
    ) -> Future<RuuviCloudPNTokenRegisterResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.registerPNToken,
                       with: requestModel,
                       method: .post,
                       authorization: authorization)
    }

    public func unregisterPNToken(
        _ requestModel: RuuviCloudPNTokenUnregisterRequest,
        authorization: String?
    ) -> Future<RuuviCloudPNTokenUnregisterResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.unregisterPNToken,
                       with: requestModel,
                       method: .post,
                       authorization: authorization)
    }

    public func listPNTokens(
        _ requestModel: RuuviCloudPNTokenListRequest,
        authorization: String
    ) -> Future<RuuviCloudPNTokenListResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.PNTokens,
                       with: requestModel,
                       method: .get,
                       authorization: authorization)
    }

    public func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiClaimResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.claim,
                       with: requestModel,
                       method: .post,
                       authorization: authorization)
    }

    public func unclaim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnclaimResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.unclaim,
                       with: requestModel,
                       method: .post,
                       authorization: authorization)
    }

    public func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiShareResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.share,
                       with: requestModel,
                       method: .post,
                       authorization: authorization)
    }

    public func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnshareResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.unshare,
                       with: requestModel,
                       method: .post,
                       authorization: authorization)
    }

    public func sensors(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorsResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.sensors,
                       with: requestModel,
                       method: .get,
                       authorization: authorization)
    }

    public func owner(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) -> Future<RuuviCloudAPICheckOwnerResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.check,
                       with: requestModel,
                       method: .get,
                       authorization: authorization)
    }

    public func sensorsDense(
        _ requestModel: RuuviCloudApiGetSensorsDenseRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorsDenseResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.sensorsDense,
                       with: requestModel,
                       method: .get,
                       authorization: authorization)
    }

    public func user(authorization: String) -> Future<RuuviCloudApiUserResponse, RuuviCloudApiError> {
        let requestModel = RuuviCloudApiUserRequest()
        return request(endpoint: Routes.user,
                       with: requestModel,
                       authorization: authorization)
    }

    public func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorResponse, RuuviCloudApiError> {
        return request(endpoint: Routes.getSensorData,
                       with: requestModel,
                       method: .get,
                       authorization: authorization)
    }

    public func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSensorUpdateResponse, RuuviCloudApiError> {
        return request(
            endpoint: Routes.update,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func resetImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSensorImageResetResponse, RuuviCloudApiError> {
        return request(
            endpoint: Routes.uploadImage,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func getSettings(
        _ requestModel: RuuviCloudApiGetSettingsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSettingsResponse, RuuviCloudApiError> {
        return request(
            endpoint: Routes.settings,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func postSetting(
        _ requestModel: RuuviCloudApiPostSettingRequest,
        authorization: String
    ) -> Future<RuuviCloudApiPostSettingResponse, RuuviCloudApiError> {
        return request(
            endpoint: Routes.settings,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func postAlert(
        _ requestModel: RuuviCloudApiPostAlertRequest,
        authorization: String
    ) -> Future<RuuviCloudApiPostAlertResponse, RuuviCloudApiError> {
        return request(
            endpoint: Routes.alerts,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func getAlerts(
        _ requestModel: RuuviCloudApiGetAlertsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetAlertsResponse, RuuviCloudApiError> {
        return request(
            endpoint: Routes.alerts,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func uploadImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        imageData: Data,
        authorization: String,
        uploadProgress: ((Double) -> Void)?
    ) -> Future<RuuviCloudApiSensorImageUploadResponse, RuuviCloudApiError> {
        let promise = Promise<RuuviCloudApiSensorImageUploadResponse, RuuviCloudApiError>()
        request(endpoint: Routes.uploadImage,
                with: requestModel,
                method: .post,
                authorization: authorization)
            .on(success: { [weak self] (response: RuuviCloudApiSensorImageUploadResponse) in
                let url = response.uploadURL
                self?.upload(url: url, with: imageData, mimeType: .jpg, progress: { percentage in
                    #if DEBUG
                    debugPrint(percentage)
                    #endif
                    uploadProgress?(percentage)
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
extension RuuviCloudApiURLSession {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func request<Request: Encodable, Response: Decodable>(
        endpoint: Routes,
        with model: Request,
        method: HttpMethod = .get,
        authorization: String? = nil
    ) -> Future<Response, RuuviCloudApiError> {
        let promise = Promise<Response, RuuviCloudApiError>()
        guard Reachability.active else {
            promise.fail(error: .connection)
            return promise.future
        }
        var url: URL = self.baseUrl.appendingPathComponent(endpoint.rawValue)
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
        if let authorization = authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let config = URLSessionConfiguration.default
        if #available(iOS 11.0, *) {
            config.waitsForConnectivity = true
            config.timeoutIntervalForResource = 30
        }
        let task = URLSession(configuration: config).dataTask(with: request) { (data, _, error) in
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
                        let baseResponse = try decoder.decode(RuuviCloudApiBaseResponse<Response>.self, from: data)
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
                        promise.fail(error: .parsing(error))
                    }
                } else {
                    promise.fail(error: .failedToGetDataFromResponse)
                }
            }
        }
        task.resume()
        return promise.future
    }
}

extension RuuviCloudApiURLSession {
    typealias Percentage = Double
    typealias ProgressHandler = (Percentage) -> Void
    typealias CompletionHandler = (Result<Data, RuuviCloudApiError>) -> Void

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
                    completion(.failure(.unexpectedHTTPStatusCode))
                } else if let data = data {
                    completion(.success(data))
                } else {
                    completion(.failure(.failedToGetDataFromResponse))
                }
            }
        )
        progressHandlersByTaskID[task.taskIdentifier] = progress
        task.resume()
    }
}

extension RuuviCloudApiURLSession: URLSessionTaskDelegate {
    public func urlSession(
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

// swiftlint:enable file_length
