import Foundation
import Future

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
        case contest = "contest-sensor"
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

// swiftlint:disable:next type_body_length
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
        request(
            endpoint: Routes.register,
            with: requestModel,
            method: .post
        )
    }

    public func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) -> Future<RuuviCloudApiVerifyResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.verify,
            with: requestModel
        )
    }

    public func deleteAccount(
        _ requestModel: RuuviCloudApiAccountDeleteRequest,
        authorization: String
    ) ->
    Future<RuuviCloudApiAccountDeleteResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.deleteAccount,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func registerPNToken(
        _ requestModel: RuuviCloudPNTokenRegisterRequest,
        authorization: String
    ) -> Future<RuuviCloudPNTokenRegisterResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.registerPNToken,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func unregisterPNToken(
        _ requestModel: RuuviCloudPNTokenUnregisterRequest,
        authorization: String?
    ) -> Future<RuuviCloudPNTokenUnregisterResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.unregisterPNToken,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func listPNTokens(
        _ requestModel: RuuviCloudPNTokenListRequest,
        authorization: String
    ) -> Future<RuuviCloudPNTokenListResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.PNTokens,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiClaimResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.claim,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func contest(
        _ requestModel: RuuviCloudApiContestRequest,
        authorization: String
    ) -> Future<RuuviCloudApiContestResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.contest,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func unclaim(
        _ requestModel: RuuviCloudApiUnclaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnclaimResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.unclaim,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiShareResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.share,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnshareResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.unshare,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func sensors(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorsResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.sensors,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func owner(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) -> Future<RuuviCloudAPICheckOwnerResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.check,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func sensorsDense(
        _ requestModel: RuuviCloudApiGetSensorsDenseRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorsDenseResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.sensorsDense,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func user(authorization: String) -> Future<RuuviCloudApiUserResponse, RuuviCloudApiError> {
        let requestModel = RuuviCloudApiUserRequest()
        return request(
            endpoint: Routes.user,
            with: requestModel,
            authorization: authorization
        )
    }

    public func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorResponse, RuuviCloudApiError> {
        request(
            endpoint: Routes.getSensorData,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSensorUpdateResponse, RuuviCloudApiError> {
        request(
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
        request(
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
        request(
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
        request(
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
        request(
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
        request(
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
        request(
            endpoint: Routes.uploadImage,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
        .on(success: { [weak self] (response: RuuviCloudApiSensorImageUploadResponse) in
            let url = response.uploadURL
            self?.upload(url: url, with: imageData, mimeType: .jpg, progress: { percentage in
                #if DEBUG || ALPHA
                    debugPrint(percentage)
                #endif
                uploadProgress?(percentage)
            }, completion: { result in
                switch result {
                case .success:
                    promise.succeed(value: response)
                case let .failure(error):
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
    private func request<Response: Decodable>(
        endpoint: Routes,
        with model: some Encodable,
        method: HttpMethod = .get,
        authorization: String? = nil
    ) -> Future<Response, RuuviCloudApiError> {
        let promise = Promise<Response, RuuviCloudApiError>()
        guard Reachability.active
        else {
            promise.fail(error: .connection)
            return promise.future
        }
        var url: URL = baseUrl.appendingPathComponent(endpoint.rawValue)
        if method == .get {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            urlComponents?.queryItems = try? URLQueryItemEncoder().encode(model)
            guard let urlFromComponents = urlComponents?.url
            else {
                fatalError()
            }
            url = urlFromComponents
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if method != .get {
            request.httpBody = try? JSONEncoder().encode(model)
        }
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            #if DEBUG || ALPHA
                request.setValue(
                    "Station_iOS_Debug/Build_\(buildNumber)/\(endpoint.rawValue)",
                    forHTTPHeaderField: "User-Agent"
                )
            #else
                request.setValue(
                    "Station_iOS/Build_\(buildNumber)/\(endpoint.rawValue)",
                    forHTTPHeaderField: "User-Agent"
                )
            #endif
        }

        let config = URLSessionConfiguration.default
        if #available(iOS 11.0, *) {
            config.waitsForConnectivity = true
            config.timeoutIntervalForResource = 30
        }
        let task = URLSession(configuration: config).dataTask(with: request) {
            data, response, error in
            if let error {
                promise.fail(error: .networking(error))
            } else {
                if let data {
                    #if DEBUG || ALPHA
                        if let object = try? JSONSerialization.jsonObject(with: data, options: []),
                           let jsonData = try? JSONSerialization.data(
                               withJSONObject: object,
                               options: [.prettyPrinted]
                           ),
                           let prettyPrintedString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue) {
                            debugPrint("📬 Response of request", dump(request), prettyPrintedString)
                        }
                    #endif
                    let decoder = JSONDecoder()
                    do {
                        let baseResponse = try decoder.decode(RuuviCloudApiBaseResponse<Response>.self, from: data)
                        switch baseResponse.result {
                        case let .success(model):
                            promise.succeed(value: model)
                        case let .failure(userApiError):
                            if let httpResponse = response as? HTTPURLResponse {
                                if httpResponse.statusCode == 500 {
                                    promise.fail(
                                        error: .unexpectedHTTPStatusCodeShouldRetry(httpResponse.statusCode)
                                    )
                                }
                                promise.fail(error: userApiError)
                            } else {
                                promise.fail(error: userApiError)
                            }
                        }
                    } catch {
                        #if DEBUG || ALPHA
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
                if let error {
                    completion(.failure(.networking(error)))
                } else if let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode != 200 {
                    completion(
                        .failure(.unexpectedHTTPStatusCode(httpResponse.statusCode))
                    )
                } else if let data {
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
        _: URLSession,
        task: URLSessionTask,
        didSendBodyData _: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let handler = progressHandlersByTaskID[task.taskIdentifier]
        handler?(progress)
    }
}

// swiftlint:enable file_length
