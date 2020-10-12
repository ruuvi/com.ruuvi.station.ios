import Foundation
import Future

extension RuuviNetworkUserApiURLSession {
    private enum Routes: String {
        case register
        case verify
        case claim
        case share
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
class RuuviNetworkUserApiURLSession: RuuviNetworkUserApi {
    var keychainService: KeychainService!

    func register(_ request: UserApiRegisterRequest) -> Future<UserApiRegisterResponse, RUError> {

    }

    func verify(_ request: UserApiVerifyRequest) -> Future<UserApiVerifyResponse, RUError> {

    }

    func claim(_ request: UserApiClaimRequest) -> Future<UserApiClaimResponse, RUError> {

    }

    func share(_ request: UserApiShareRequest) -> Future<UserApiShareResponse, RUError> {

    }

    func user() -> Future<UserApiUserResponse, RUError> {

    }

    func getSensorData(_ request: UserApiGetSensorRequest) -> Future<UserApiGetSensorResponse, RUError> {

    }

    func update(_ request: UserApiSensorUpdateRequest) -> Future<UserApiSensorUpdateResponse, RUError> {

    }

    func uploadImage(_ request: UserApiSensorImageUploadRequest, imageData: Data) -> Future<UserApiSensorImageUploadResponse, RUError> {

    }
}

// MARK: - Private
extension RuuviNetworkUserApiURLSession {
    private func request<Request:Encodable, Response: Decodable>(endpoint: Routes,
                                                                 with model: Request.Type,
                                                                 handledType: Response.Type,
                                                                 method: HttpMethod = .get,
                                                                 authorizationRequered: Bool = false) -> Future<Response.Type, RUError> {
        let promise = Promise<Response.Type, RUError>()
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = method.rawValue
        request.httpBody = try? JSONEncoder().encode(Request.self)
        if authorizationRequered {
            request.setValue(keychainService.ruuviUserApiKey, forHTTPHeaderField: "Authorization")
        }
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                promise.fail(error: .networking(error))
            } else {
                if let data = data {
                    let decoder = JSONDecoder()
                    do {
                        let result = try decoder.decode(UserApiBaseResponse<Response>.self, from: data)
                        if let responseTyped = result.data as? Response.Type {
                            promise.succeed(value: responseTyped.self)
                        } else {
                            promise.fail(error: .parse(error))
                        }
                    } catch let error {
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
