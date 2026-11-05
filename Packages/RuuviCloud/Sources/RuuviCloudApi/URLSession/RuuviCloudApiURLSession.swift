#if SWIFT_PACKAGE
    import RuuviOntology
#endif
import Foundation
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
        case contest = "contest-sensor"
        case unclaim
        case share
        case unshare
        case user
        case getSensorData = "get"
        case update
        case uploadImage = "upload"
        case settings
        case marketingConsent = "marketing-consent"
        case sensorSettings = "sensor-settings"
        case sensors
        case sensorsDense = "sensors-dense"
        case alerts
        case check
    }
}

// swiftlint:disable:next type_body_length
public final class RuuviCloudApiURLSession: NSObject, RuuviCloudApi {
    private let baseUrl: URL
    private let session: URLSession

    public init(baseUrl: URL, session: URLSession? = nil) {
        self.baseUrl = baseUrl
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: configuration)
        }
        super.init()
    }

    public func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiRegisterResponse {
        try await request(
            endpoint: Routes.register,
            with: requestModel,
            method: .post
        )
    }

    public func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiVerifyResponse {
        try await request(
            endpoint: Routes.verify,
            with: requestModel
        )
    }

    public func deleteAccount(
        _ requestModel: RuuviCloudApiAccountDeleteRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiAccountDeleteResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudPNTokenRegisterResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudPNTokenUnregisterResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudPNTokenListResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiClaimResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiContestResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiUnclaimResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiShareResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiUnshareResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetSensorsResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudAPICheckOwnerResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetSensorsDenseResponse {
        try await request(
            endpoint: Routes.sensorsDense,
            with: requestModel,
            method: .get,
            authorization: authorization
        )
    }

    public func user(authorization: String) async throws(RuuviCloudApiError) -> RuuviCloudApiUserResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetSensorResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiSensorUpdateResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiSensorImageResetResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetSettingsResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiPostSettingResponse {
        try await request(
            endpoint: Routes.settings,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func getMarketingConsent(
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudMarketingConsent {
        try await request(
            endpoint: Routes.marketingConsent,
            with: RuuviCloudApiGetMarketingConsentRequest(),
            method: .get,
            authorization: authorization
        )
    }

    public func setMarketingConsent(
        _ requestModel: RuuviCloudApiSetMarketingConsentRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudMarketingConsent {
        try await request(
            endpoint: Routes.marketingConsent,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
    }

    public func postSensorSettings(
        _ requestModel: RuuviCloudApiPostSensorSettingsRequest,
        authorization: String
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiPostSensorSettingsResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiPostAlertResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiGetAlertsResponse {
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
    ) async throws(RuuviCloudApiError) -> RuuviCloudApiSensorImageUploadResponse {
        let response: RuuviCloudApiSensorImageUploadResponse = try await self.request(
            endpoint: Routes.uploadImage,
            with: requestModel,
            method: .post,
            authorization: authorization
        )
        var request = URLRequest(url: response.uploadURL)
        request.httpMethod = HttpMethod.put.rawValue
        request.setValue((requestModel.mimeType ?? .jpg).rawValue, forHTTPHeaderField: "Content-Type")
        let delegate = UploadProgressDelegate(progress: uploadProgress)
        defer { delegate.finish() }
        do {
            let (_, result) = try await session.upload(
                for: request,
                from: imageData,
                delegate: delegate
            )
            guard let http = result as? HTTPURLResponse else {
                throw RuuviCloudApiError.failedToGetDataFromResponse
            }
            if (500..<600).contains(http.statusCode) {
                throw RuuviCloudApiError.unexpectedHTTPStatusCodeShouldRetry(http.statusCode)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw RuuviCloudApiError.unexpectedHTTPStatusCode(http.statusCode)
            }
            return response
        } catch let error as RuuviCloudApiError {
            throw error
        } catch {
            throw .networking(error)
        }
    }
}

// MARK: - Private

extension RuuviCloudApiURLSession {
    private func request<Response: Decodable>(
        endpoint: Routes,
        with model: some Encodable,
        method: HttpMethod = .get,
        authorization: String? = nil
    ) async throws(RuuviCloudApiError) -> Response {
        var url = baseUrl.appendingPathComponent(endpoint.rawValue)
        var body: Data?
        do {
            if method == .get {
                guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                    throw RuuviCloudApiError.badParameters
                }
                components.queryItems = try RuuviCloudQuery.items(for: model)
                guard let encodedURL = components.url else { throw RuuviCloudApiError.badParameters }
                url = encodedURL
            } else {
                body = try JSONEncoder().encode(model)
            }
        } catch let error as RuuviCloudApiError { throw error } catch { throw .badParameters }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authorization { request.setValue(authorization, forHTTPHeaderField: "Authorization") }
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            #if DEBUG || ALPHA
                let client = "Station_iOS_Debug"
            #else
                let client = "Station_iOS"
            #endif
            request.setValue("\(client)/Build_\(build)/\(endpoint.rawValue)", forHTTPHeaderField: "User-Agent")
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw .networking(error) }
        guard let http = response as? HTTPURLResponse else { throw .failedToGetDataFromResponse }
        if (500..<600).contains(http.statusCode) {
            throw .unexpectedHTTPStatusCodeShouldRetry(http.statusCode)
        }
        let decoded: RuuviCloudApiBaseResponse<Response>
        do { decoded = try JSONDecoder().decode(RuuviCloudApiBaseResponse<Response>.self, from: data) } catch {
            if !(200..<300).contains(http.statusCode) { throw .unexpectedHTTPStatusCode(http.statusCode) }
            throw .parsing(error)
        }
        switch decoded.result {
        case let .success(value):
            guard (200..<300).contains(http.statusCode) else { throw .unexpectedHTTPStatusCode(http.statusCode) }
            return value
        case let .failure(error):
            throw error
        }
    }
}

/// One delegate per upload avoids shared handler storage and releases the callback with the task.
private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let progress: ((Double) -> Void)?
    private let lock = NSLock()
    private var isActive = true

    func finish() { lock.withLock { isActive = false } }

    init(progress: ((Double) -> Void)?) { self.progress = progress }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = min(1, max(0, Double(totalBytesSent) / Double(totalBytesExpectedToSend)))
        // Upload progress was previously delivered on the main delegate queue.
        DispatchQueue.main.async { [self] in
            guard lock.withLock({ isActive }) else { return }
            progress?(fraction)
        }
    }
}
