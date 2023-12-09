import Foundation

public struct RuuviCloudApiBaseResponse<T: Any>: Decodable where T: Decodable {
    enum Status: String, Decodable {
        case success
        case error
    }

    private let status: Status
    private let data: T?
    private let errorDescription: String?
    private let code: RuuviCloudApiErrorCode?
    private let subCode: RuuviCloudApiErrorCode?

    enum CodingKeys: String, CodingKey {
        case status = "result"
        case data
        case errorDescription = "error"
        case code
        case subCode
    }
}

public extension RuuviCloudApiBaseResponse {
    var result: Swift.Result<T, RuuviCloudApiError> {
        switch status {
        case .success:
            guard let data
            else {
                if let emptyModel = T.emptyModel {
                    return .success(emptyModel)
                } else {
                    return .failure(.emptyResponse)
                }
            }
            return .success(data)
        case .error:
            guard let code
            else {
                if errorDescription != nil {
                    return .failure(.api(.erInternal))
                } else {
                    return .failure(.emptyResponse)
                }
            }

            if code == .erUnauthorized {
                return .failure(.unauthorized)
            }

            return .failure(.api(code))
        }
    }
}

public extension Decodable {
    static var emptyModel: Self? {
        let emptyString = "{}"
        if let emptyData = emptyString.data(using: .utf8),
           let emptyModel = try? JSONDecoder().decode(self, from: emptyData) {
            return emptyModel
        } else {
            return nil
        }
    }
}
