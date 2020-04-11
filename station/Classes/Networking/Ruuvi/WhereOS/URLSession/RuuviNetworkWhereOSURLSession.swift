import Foundation
import Future

class RuuviNetworkWhereOSURLSession: RuuviNetworkWhereOS {

    func load(mac: String) -> Future<[WhereOSData], RUError> {
        let promise = Promise<[WhereOSData], RUError>()
        if let url = whereOSDataURL(mac: mac) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    if let error = error {
                        promise.fail(error: .networking(error))
                    } else {
                        if let data = data {
                            let decoder = JSONDecoder()
                            let formatter = DateFormatter()
                            decoder.keyDecodingStrategy = .convertFromSnakeCase
                            decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
                                let container = try decoder.singleValueContainer()
                                let dateStr = try container.decode(String.self)
                                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                                if let date = formatter.date(from: dateStr) {
                                    return date
                                }
                                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted.")
                            })
                            do {
                                let result = try decoder.decode([WhereOSData].self, from: data)
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
            } else {
                promise.fail(error: .unexpected(.failedToConstructURL))
            }
            return promise.future
    }

    private func whereOSDataURL(mac: String) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "whereos.ruuvi.com"
        urlComponents.path = "/api/ruuvi/tag/\(justified(mac: mac))"

        let aggregationQuery = URLQueryItem(name: "p_aggregation", value: "1h")
        urlComponents.queryItems = [aggregationQuery]

        return urlComponents.url
    }

    private func justified(mac: String) -> String {
        return mac.replacingOccurrences(of: ":", with: "").lowercased()
    }
}
