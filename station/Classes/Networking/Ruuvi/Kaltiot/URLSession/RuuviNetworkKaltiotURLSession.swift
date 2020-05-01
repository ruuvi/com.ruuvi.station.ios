import Foundation
import Future
import BTKit
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
                    200...204 ~= response.statusCode {
                    promise.succeed(value: ())
                } else {
                    promise.fail(error: .ruuviNetwork(.failedToLogIn))
                }
            }
        }
        task.resume()
        return promise.future
    }

    func beacons(page: Int) -> Future<KaltiotBeacons, RUError> {
        guard keychainService.hasKaltiotApiKey else {
            return .init(error: .ruuviNetwork(.noSavedApiKeyValue))
        }
        let promise = Promise<KaltiotBeacons, RUError>()
        let params: [String: String] = [
            "complete": "true",
            "page": String(page)
        ]
        guard let url = url(for: .beacons, params: params) else {
            return .init(error: .unexpected(.failedToConstructURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let response = response as? HTTPURLResponse,
                200...204 ~= response.statusCode else {
                    self?.keychainService.kaltiotApiKey = nil
                    promise.fail(error: .ruuviNetwork(.failedToLogIn))
                    return
            }
            if let error = error {
                promise.fail(error: .networking(error))
            } else {
                if let data = data {
                    let decoder = JSONDecoder()
                    do {
                        let result = try decoder.decode(KaltiotBeacons.self, from: data)
                        promise.succeed(value: result)
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

    func history(ids: [String], from: TimeInterval?, to: TimeInterval?) -> Future<[KaltiotBeaconLogs], RUError> {
        guard keychainService.hasKaltiotApiKey else {
            return .init(error: .ruuviNetwork(.noSavedApiKeyValue))
        }
        let promise = Promise<[KaltiotBeaconLogs], RUError>()
        let idsString: String = ids.reduce("") { (result, item) -> String in
            var string = result
            if item != ids.last {
                string += ","
            }
            string += item
            return string
        }
        var params: [String: String] = [
            "ids": idsString
        ]
        if let from = from {
            params["from"] = String(from)
        }
        if let to = to {
            params["to"] = String(to)
        }
        guard let url = url(for: .sensorHistory, params: params) else {
            return .init(error: .unexpected(.failedToConstructURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let response = response as? HTTPURLResponse,
                200...204 ~= response.statusCode else {
                    self?.keychainService.kaltiotApiKey = nil
                    promise.fail(error: .ruuviNetwork(.failedToLogIn))
                    return
            }
            if let error = error {
                promise.fail(error: .networking(error))
            } else {
                if let data = data {
                    let decoder = JSONDecoder()
                    do {
                        let result = try decoder.decode(Array<KaltiotBeaconLogs>.self, from: data)
                        promise.succeed(value: result)
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

// MARK: - Private
    private lazy var baseUrlComponents: URLComponents = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "beacontracker.ruuvi.torqhub.io"
        components.path = "/api"
        return components
    }()

    private enum Resources {
        case appid
        case sensorHistory
        case beacons

        var endpoint: String {
            switch self {
            case .appid:
                return "/appid"
            case .beacons:
                return "/beacons"
            case .sensorHistory:
                return "/history/sensor/hexdump"
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
