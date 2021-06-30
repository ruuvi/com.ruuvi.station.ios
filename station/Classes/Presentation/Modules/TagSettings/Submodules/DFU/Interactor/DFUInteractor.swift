import Foundation
import Combine

protocol DFUInteractorInput {
    @discardableResult
    func fetchLatestRuuviTagFirmwareVersion() -> Future<String, DFUError>
}

final class DFUInteractor {
}

enum DFUError: Error {
    case networking(Error)
    case parsing(Error)
    case failedToConstructUrl
    case failedToParseGithubResponse
}

extension DFUInteractor: DFUInteractorInput {
    @discardableResult
    func fetchLatestRuuviTagFirmwareVersion() -> Future<String, DFUError> {
        return Future { promise in
            guard let latestReleaseUrl = URL(
                    string: "https://api.github.com/repos/ruuvi/ruuvi.firmware.c/releases/latest"
            ) else {
                promise(.failure(.failedToConstructUrl))
                return
            }
            var request = URLRequest(url: latestReleaseUrl)
            request.httpMethod = "GET"
            let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
                if let error = error {
                    promise(.failure(.networking(error)))
                } else {
                    if let data = data {
                        do {
                            guard let json = try JSONSerialization.jsonObject(with:
                                data, options: []) as? [String: Any] else {
                                promise(.failure(.failedToParseGithubResponse))
                                return
                            }
                            guard let tagName = json["tag_name"] as? String else {
                                promise(.failure(.failedToParseGithubResponse))
                                return
                            }
                            promise(.success(tagName))
                        } catch let error {
                            promise(.failure(.parsing(error)))
                            return
                        }
                    } else {
                        promise(.failure(.failedToParseGithubResponse))
                        return
                    }
                }
            }
            task.resume()
        }
    }
}
