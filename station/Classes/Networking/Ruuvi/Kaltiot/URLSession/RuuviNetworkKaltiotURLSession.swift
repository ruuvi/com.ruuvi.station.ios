import Foundation
import Future

class RuuviNetworkKaltiotURLSession: RuuviNetworkKaltiot {

    var keychainService: KeychainService!

    func validateApiKey(apiKey: String) -> Future<Void, RUError> {
        guard let url = url(for: .appid, params: ["ApiKey": apiKey]) else {
            return .init(error: .unexpected(.failedToConstructURL))
        }
        let promise = Promise<Void, RUError>()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
            if let error = error {
                promise.fail(error: .networking(error))
            } else {
                if let response = response as? HTTPURLResponse,
                    response.statusCode == 200 {
                    promise.succeed(value: ())
                } else {
                    promise.fail(error: .ruuviNetwork(.failedToLogIn))
                }
            }
        }
        task.resume()
        return promise.future
    }

    private lazy var baseUrlComponents: URLComponents = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "beacontracker.ruuvi.torqhub.io"
        components.path = "/api"
        return components
    }()

    enum Resources {
        case appid
        case sensorHistory


        var endpoint: String {
            switch self {
            case .appid:
                return "/appid/"
            case .sensorHistory:
                return "/history/sensor/hexdump/"
            }
        }
    }

    private func url(for resource: Resources,
                     params: [String: String] = [:]) -> URL? {
        var components = baseUrlComponents
        components.path += resource.endpoint
        var queryItems: [URLQueryItem] = []
        params.forEach({
            if !$0.value.isEmpty {
                queryItems.append(.init(name: $0.key, value: $0.value))
            }
        })
        if keychainService.hasKaltiotApiKey {
            queryItems.append(.init(name: "ApiKey", value: keychainService.kaltiotApiKey))
        }
        components.queryItems = queryItems
        return components.url
    }
}
