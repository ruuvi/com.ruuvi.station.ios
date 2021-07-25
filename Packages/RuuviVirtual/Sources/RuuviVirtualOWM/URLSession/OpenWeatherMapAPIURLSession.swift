import Foundation
import Future
import RuuviVirtual

public final class OpenWeatherMapAPIURLSession: OpenWeatherMapAPI {
    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func loadCurrent(
        longitude: Double,
        latitude: Double
    ) -> Future<OWMData, OWMError> {
        let promise = Promise<OWMData, OWMError>()
        if let url = currentWeatherUrl(latitude: latitude, longitude: longitude) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    promise.fail(error: .networking(error))
                } else {
                    if let httpResponse = response as? HTTPURLResponse {
                        let status = httpResponse.statusCode
                        if status == 429 {
                            promise.fail(error: OWMError.apiLimitExceeded)
                        } else if status == 401 {
                            promise.fail(error: OWMError.invalidApiKey)
                        } else {
                            if let data = data {
                                do {
                                    guard let json = try JSONSerialization.jsonObject(with:
                                        data, options: []) as? [String: Any] else {
                                            promise.fail(error: OWMError.failedToParseOpenWeatherMapResponse)
                                            return
                                    }
                                    guard let main = json["main"] as? [String: Any] else {
                                        promise.fail(error: OWMError.failedToParseOpenWeatherMapResponse)
                                        return
                                    }
                                    let kelvin = main["temp"] as? Double
                                    let humidity = main["humidity"] as? Double
                                    let pressure = main["pressure"] as? Double
                                    let data = OWMData(kelvin: kelvin, humidity: humidity, pressure: pressure)
                                    promise.succeed(value: data)
                                } catch let error {
                                    promise.fail(error: .networking(error))
                                }
                            } else {
                                promise.fail(error: OWMError.failedToParseOpenWeatherMapResponse)
                            }
                        }
                    } else {
                        promise.fail(error: OWMError.notAHttpResponse)
                    }
                }
            }
            task.resume()
        } else {
            promise.fail(error: .missingOpenWeatherMapAPIKey)
        }
        return promise.future
    }

    private func currentWeatherUrl(latitude: Double, longitude: Double) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.openweathermap.org"
        urlComponents.path = "/data/2.5/weather"

        let latitudeQuery = URLQueryItem(name: "lat", value: "\(latitude)")
        let longitudeQuery = URLQueryItem(name: "lon", value: "\(longitude)")
        let apiKeyQuery = URLQueryItem(name: "APPID", value: apiKey)
        urlComponents.queryItems = [latitudeQuery, longitudeQuery, apiKeyQuery]

        return urlComponents.url
    }
}
