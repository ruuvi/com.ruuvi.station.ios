import Foundation

// swiftlint:disable file_length

protocol RuuviCloudTasking: AnyObject {
    var taskIdentifier: Int { get }
    func resume()
}

extension URLSessionTask: RuuviCloudTasking {}

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
        case sensorSettings = "sensor-settings"
        case sensors
        case sensorsDense = "sensors-dense"
        case alerts
        case check
    }
}

// swiftlint:disable:next type_body_length
public final class RuuviCloudApiURLSession: NSObject, RuuviCloudApi {
    typealias DataLoader = (URLRequest) async throws -> (Data, URLResponse)
    typealias UploadPerformer = (URLRequest, Data, @escaping ProgressHandler) async throws -> Data
    typealias RequestCompletion = (Data?, URLResponse?, Error?) -> Void
    typealias UploadCompletion = (Data?, URLResponse?, Error?) -> Void
    typealias DataTaskFactory = (URLRequest, @escaping RequestCompletion) -> RuuviCloudTasking
    typealias UploadTaskFactory = (URLRequest, Data, @escaping UploadCompletion) -> RuuviCloudTasking

    private lazy var uploadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.protocolClasses = urlProtocolClasses
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
    private let dataLoader: DataLoader?
    private let uploadPerformer: UploadPerformer?
    private let dataTaskFactory: DataTaskFactory?
    private let uploadTaskFactory: UploadTaskFactory?
    private let isReachable: () -> Bool
    private let buildNumberProvider: () -> String?
    private let urlProtocolClasses: [AnyClass]?

    public init(baseUrl: URL) {
        self.baseUrl = baseUrl
        dataLoader = nil
        uploadPerformer = nil
        dataTaskFactory = nil
        uploadTaskFactory = nil
        isReachable = { Reachability.active }
        buildNumberProvider = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        }
        urlProtocolClasses = nil
        Reachability.start()
    }

    init(
        baseUrl: URL,
        isReachable: @escaping () -> Bool,
        buildNumberProvider: @escaping () -> String?,
        dataLoader: DataLoader? = nil,
        uploadPerformer: UploadPerformer? = nil,
        dataTaskFactory: DataTaskFactory? = nil,
        uploadTaskFactory: UploadTaskFactory? = nil,
        urlProtocolClasses: [AnyClass]? = nil
    ) {
        self.baseUrl = baseUrl
        self.dataLoader = dataLoader
        self.uploadPerformer = uploadPerformer
        self.dataTaskFactory = dataTaskFactory
        self.uploadTaskFactory = uploadTaskFactory
        self.isReachable = isReachable
        self.buildNumberProvider = buildNumberProvider
        self.urlProtocolClasses = urlProtocolClasses
    }

    func dependencySnapshotForTesting() -> (isReachable: Bool, buildNumber: String?) {
        (isReachable(), buildNumberProvider())
    }

    func getForTesting<Response: Decodable>(
        model: some Encodable
    ) async throws -> Response {
        try await request(endpoint: .verify, with: model)
    }

    public func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) async throws -> RuuviCloudApiRegisterResponse {
        try await request(
            endpoint: Routes.register,
            with: requestModel,
            method: .post
        )
    }

    public func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) async throws -> RuuviCloudApiVerifyResponse {
        try await request(
            endpoint: Routes.verify,
            with: requestModel
        )
    }

    public func deleteAccount(
        _ requestModel: RuuviCloudApiAccountDeleteRequest,
        authorization: String
    ) async throws -> RuuviCloudApiAccountDeleteResponse {
        try await request(
            endpoint: Routes.deleteAccount,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func registerPNToken(
        _ requestModel: RuuviCloudPNTokenRegisterRequest,
        authorization: String
    ) async throws -> RuuviCloudPNTokenRegisterResponse {
        try await request(
            endpoint: Routes.registerPNToken,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func unregisterPNToken(
        _ requestModel: RuuviCloudPNTokenUnregisterRequest,
        authorization: String?
    ) async throws -> RuuviCloudPNTokenUnregisterResponse {
        try await request(
            endpoint: Routes.unregisterPNToken,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func listPNTokens(
        _ requestModel: RuuviCloudPNTokenListRequest,
        authorization: String
    ) async throws -> RuuviCloudPNTokenListResponse {
        try await request(
            endpoint: Routes.PNTokens,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) async throws -> RuuviCloudApiClaimResponse {
        try await request(
            endpoint: Routes.claim,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func contest(
        _ requestModel: RuuviCloudApiContestRequest,
        authorization: String
    ) async throws -> RuuviCloudApiContestResponse {
        try await request(
            endpoint: Routes.contest,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func unclaim(
        _ requestModel: RuuviCloudApiUnclaimRequest,
        authorization: String
    ) async throws -> RuuviCloudApiUnclaimResponse {
        try await request(
            endpoint: Routes.unclaim,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) async throws -> RuuviCloudApiShareResponse {
        try await request(
            endpoint: Routes.share,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) async throws -> RuuviCloudApiUnshareResponse {
        try await request(
            endpoint: Routes.unshare,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func sensors(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorsResponse {
        try await request(
            endpoint: Routes.sensors,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func owner(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) async throws -> RuuviCloudAPICheckOwnerResponse {
        try await request(
            endpoint: Routes.check,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func sensorsDense(
        _ requestModel: RuuviCloudApiGetSensorsDenseRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorsDenseResponse {
        try await request(
            endpoint: Routes.sensorsDense,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func user(authorization: String) async throws -> RuuviCloudApiUserResponse {
        let requestModel = RuuviCloudApiUserRequest()
        return try await request(
            endpoint: Routes.user,
            with: requestModel,
            authorization: authorization
        )
    }

    public func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorResponse {
        try await request(
            endpoint: Routes.getSensorData,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) async throws -> RuuviCloudApiSensorUpdateResponse {
        try await request(
            endpoint: Routes.update,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func resetImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        authorization: String
    ) async throws -> RuuviCloudApiSensorImageResetResponse {
        try await request(
            endpoint: Routes.uploadImage,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func getSettings(
        _ requestModel: RuuviCloudApiGetSettingsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSettingsResponse {
        try await request(
            endpoint: Routes.settings,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func postSetting(
        _ requestModel: RuuviCloudApiPostSettingRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostSettingResponse {
        try await request(
            endpoint: Routes.settings,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func postSensorSettings(
        _ requestModel: RuuviCloudApiPostSensorSettingsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostSensorSettingsResponse {
        try await request(
            endpoint: Routes.sensorSettings,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func postAlert(
        _ requestModel: RuuviCloudApiPostAlertRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostAlertResponse {
        try await request(
            endpoint: Routes.alerts,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func getAlerts(
        _ requestModel: RuuviCloudApiGetAlertsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetAlertsResponse {
        try await request(
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
    ) async throws -> RuuviCloudApiSensorImageUploadResponse {
        let response: RuuviCloudApiSensorImageUploadResponse = try await request(
            endpoint: Routes.uploadImage,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
        _ = try await upload(
            url: response.uploadURL,
            with: imageData,
            mimeType: requestModel.mimeType ?? .jpg,
            progress: { percentage in
                #if DEBUG || ALPHA
                    debugPrint(percentage)
                #endif
                uploadProgress?(percentage)
            }
        )
        return response
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
    ) async throws -> Response {
        guard isReachable() else { throw RuuviCloudApiError.connection }
        var url: URL = baseUrl.appendingPathComponent(endpoint.rawValue)
        if method == .get {
            let queryItems: [URLQueryItem]
            do {
                queryItems = try URLQueryItemEncoder().encode(model)
            } catch {
                throw RuuviCloudApiError.badParameters
            }
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            urlComponents.queryItems = queryItems
            url = urlComponents.url!
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if method != .get {
            do {
                request.httpBody = try JSONEncoder().encode(model)
            } catch {
                throw RuuviCloudApiError.badParameters
            }
        }
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let buildNumber = buildNumberProvider() {
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

        let (data, response) = try await performRequest(request)
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
                return model
            case let .failure(userApiError):
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 500 {
                    throw RuuviCloudApiError.unexpectedHTTPStatusCodeShouldRetry(httpResponse.statusCode)
                }
                throw userApiError
            }
        } catch let error as RuuviCloudApiError {
            throw error
        } catch {
            #if DEBUG || ALPHA
                debugPrint("❌ Parsing Error", dump(error))
            #endif
            throw RuuviCloudApiError.parsing(error)
        }
    }
}

extension RuuviCloudApiURLSession {
    typealias Percentage = Double
    typealias ProgressHandler = (Percentage) -> Void
    private func upload(
        url: URL,
        with data: Data,
        mimeType: MimeType,
        method: HttpMethod = .put,
        progress: @escaping ProgressHandler
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(mimeType.rawValue, forHTTPHeaderField: "Content-Type")
        if let uploadPerformer {
            return try await uploadPerformer(request, data, progress)
        }
        return try await performUpload(request, data: data, progress: progress)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        if let dataLoader {
            return try await dataLoader(request)
        }
        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
            let task: RuuviCloudTasking
            if let dataTaskFactory {
                task = dataTaskFactory(request) { data, response, error in
                    Self.resumeRequestContinuation(
                        continuation,
                        data: data,
                        response: response,
                        error: error
                    )
                }
            } else {
                let config = URLSessionConfiguration.default
                config.protocolClasses = urlProtocolClasses
                if #available(iOS 11.0, *) {
                    config.waitsForConnectivity = true
                    config.timeoutIntervalForResource = 30
                }
                let session = URLSession(configuration: config)
                task = session.dataTask(with: request) { data, response, error in
                    Self.resumeRequestContinuation(
                        continuation,
                        data: data,
                        response: response,
                        error: error
                    )
                }
            }
            task.resume()
        }
    }

    private static func resumeRequestContinuation(
        _ continuation: CheckedContinuation<(Data, URLResponse), Error>,
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) {
        if let error {
            continuation.resume(throwing: RuuviCloudApiError.networking(error))
        } else if let data, let response {
            continuation.resume(returning: (data, response))
        } else {
            continuation.resume(throwing: RuuviCloudApiError.failedToGetDataFromResponse)
        }
    }

    private func performUpload(
        _ request: URLRequest,
        data: Data,
        progress: @escaping ProgressHandler
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Data, Error>) in
            var taskIdentifier: Int?
            let completion: UploadCompletion = { [weak self] data, response, error in
                defer {
                    if let taskIdentifier {
                        self?.progressHandlersByTaskID.removeValue(forKey: taskIdentifier)
                    }
                }
                if let error {
                    continuation.resume(throwing: RuuviCloudApiError.networking(error))
                } else if let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode != 200 {
                    continuation.resume(
                        throwing: RuuviCloudApiError.unexpectedHTTPStatusCode(httpResponse.statusCode)
                    )
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: RuuviCloudApiError.failedToGetDataFromResponse)
                }
            }
            let task: RuuviCloudTasking
            if let uploadTaskFactory {
                task = uploadTaskFactory(request, data, completion)
            } else {
                task = uploadSession.uploadTask(
                    with: request,
                    from: data,
                    completionHandler: completion
                )
            }
            taskIdentifier = task.taskIdentifier
            progressHandlersByTaskID[task.taskIdentifier] = progress
            task.resume()
        }
    }

    func handleUploadProgress(
        taskIdentifier: Int,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let handler = progressHandlersByTaskID[taskIdentifier]
        handler?(progress)
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
        handleUploadProgress(
            taskIdentifier: task.taskIdentifier,
            totalBytesSent: totalBytesSent,
            totalBytesExpectedToSend: totalBytesExpectedToSend
        )
    }
}

// swiftlint:enable file_length
