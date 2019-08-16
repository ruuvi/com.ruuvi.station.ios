import Foundation
import Future

class OpenWeatherMapAPIURLSession: OpenWeatherMapAPI {
    
    var apiKey: String = "provide api key in the /Classes/Networking/Assembly/Networking.plist file, NOT HERE!"
    var baseUrl: String = "https://api.openweathermap.org/data/2.5/"
    
    func loadCurrent(longitude: Double, latitude: Double) -> Future<OWMData,RUError> {
        let promise = Promise<OWMData,RUError>()
        let string = baseUrl + "weather?lat=\(latitude)&lon=\(longitude)&APPID=\(apiKey)"
        if let url = URL(string: string) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    promise.fail(error: .networking(error))
                } else {
                    if let httpResponse = response as? HTTPURLResponse {
                        let status = httpResponse.statusCode
                        if status == 429 {
                            promise.fail(error: .parse(OWMError.apiLimitExceeded))
                        } else {
                            if let data = data {
                                do {
                                    guard let json = try JSONSerialization.jsonObject(with:
                                        data, options: []) as? [String: Any] else {
                                            promise.fail(error: .parse(OWMError.failedToParseOpenWeatherMapResponse))
                                            return
                                    }
                                    guard let main = json["main"] as? [String: Any] else {
                                        promise.fail(error: .parse(OWMError.failedToParseOpenWeatherMapResponse))
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
                                promise.fail(error: .parse(OWMError.failedToParseOpenWeatherMapResponse))
                            }
                        }
                    } else {
                        promise.fail(error: .parse(OWMError.notAHttpResponse))
                    }
                }
            }
            task.resume()
        } else {
            promise.fail(error: .expected(.missingOpenWeatherMapAPIKey))
        }
        return promise.future
    }
}
